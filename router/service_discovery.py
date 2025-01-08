from typing import List, Dict, Optional
import threading
import abc
import enum
from kubernetes import client, config, watch

from log import init_logger
logger = init_logger(__name__)

_global_service_discovery: "Optional[ServiceDiscovery]" = None

def check_pod_ready(container_statuses):
    if not container_statuses:
        return False
    ready_count = sum(1 for status in container_statuses if status.ready)
    return ready_count == len(container_statuses)

class ServiceDiscoveryType(enum.Enum):
    STATIC = "static"
    K8S = "k8s"

class ServiceDiscovery(metaclass = abc.ABCMeta):
    @abc.abstractmethod
    def get_engine_urls(self) -> List[str]:
        """
        Get the URLs of the serving engines that are available for
        querying.

        Returns:
            a list of engine URLs
        """
        pass


class StaticServiceDiscovery(ServiceDiscovery):
    def __init__(self, urls: List[str]):
        self.urls = urls

    def get_engine_urls(self) -> List[str]:
        """
        Get the URLs of the serving engines that are available for
        querying.

        Returns:
            a list of engine URLs
        """
        return self.urls


class K8sServiceDiscovery(ServiceDiscovery):
    def __init__(self, namespace: str, port: str, label_selector = None):
        """
        Initialize the Kubernetes service discovery module. This module 
        assumes all serving engine pods are in the same namespace, listening
        on the same port, and have the same label selector.

        It will start a daemon thread to watch the engine pods and update
        the url of the available engines.

        Args:
            namespace: the namespace of the engine pods
            port: the port of the engines
            label_selector: the label selector of the engines
        """
        self.namespace = namespace
        self.port = port
        self.available_engines: Dict[str, str] = {}
        self.available_engines_lock = threading.Lock()
        self.label_selector = label_selector

        # Init kubernetes watcher
        try:
            config.load_incluster_config()
        except:
            config.load_kube_config()

        self.k8s_api = client.CoreV1Api()
        self.k8s_watcher = watch.Watch()

        # Start watching engines
        self.watcher_thread = threading.Thread(
                target=self._watch_engines,
                daemon=True)
        self.watcher_thread.start()

    def _watch_engines(self):
        # TODO (ApostaC): Add error handling

        for event in self.k8s_watcher.stream(
            self.k8s_api.list_namespaced_pod,
            namespace=self.namespace,
            label_selector=self.label_selector,
        ):
            pod = event["object"]
            event_type = event["type"]
            pod_name = pod.metadata.name
            pod_ip = pod.status.pod_ip
            is_pod_ready = check_pod_ready(pod.status.container_statuses)
            self._on_engine_update(pod_name, pod_ip, event_type, is_pod_ready)

    def _add_engine(self, engine_name: str, engine_ip: str):
        logger.info(f"Discovered new serving engine {engine_name} at "
                    f"{engine_ip}")
        with self.available_engines_lock:
            self.available_engines[engine_name] = engine_ip

    def _delete_engine(self, engine_name: str):
        logger.info(f"Serving engine {engine_name} is deleted")
        with self.available_engines_lock:
            del self.available_engines[engine_name]

    def _on_engine_update(
            self, 
            engine_name: str,
            engine_ip: Optional[str],
            event: str,
            is_pod_ready: bool,
        ) -> None:
        if event == "ADDED":
            if engine_ip is None:
                return

            if not is_pod_ready:
                return

            self._add_engine(engine_name, engine_ip)

        elif event == "DELETED":
            if engine_name not in self.available_engines:
                return

            self._delete_engine(engine_name)
        
        elif event == "MODIFIED":
            if engine_ip is None:
                return

            if is_pod_ready:
                self._add_engine(engine_name, engine_ip)
                return

            if not is_pod_ready and \
                    engine_name in self.available_engines:
                self._delete_engine(engine_name)
                return 

    def get_engine_urls(self) -> List[str]:
        """
        Get the URLs of the serving engines that are available for
        querying.

        Returns:
            a list of engine URLs
        """
        with self.available_engines_lock:
            return [
                f"http://{ip}:{self.port}" for ip in self.available_engines.values()
            ]

def InitializeServiceDiscovery(
        service_discovery_type: ServiceDiscoveryType,
        *args, **kwargs) -> ServiceDiscovery:
    """
    Initialize the service discovery module with the given type and arguments.

    Args:
        service_discovery_type: the type of service discovery module
        *args: positional arguments for the service discovery module
        **kwargs: keyword arguments for the service discovery module

    Returns:
        the initialized service discovery module

    Raises:
        ValueError: if the service discovery module is already initialized
        ValueError: if the service discovery type is invalid
    """
    global _global_service_discovery
    if _global_service_discovery is not None:
        raise ValueError("Service discovery module already initialized")

    if service_discovery_type == ServiceDiscoveryType.STATIC:
        _global_service_discovery = StaticServiceDiscovery(*args, **kwargs)
    elif service_discovery_type == ServiceDiscoveryType.K8S:
        _global_service_discovery = K8sServiceDiscovery(*args, **kwargs)
    else:
        raise ValueError("Invalid service discovery type")

    return _global_service_discovery

def GetServiceDiscovery() -> ServiceDiscovery:
    """
    Get the initialized service discovery module.

    Returns:
        the initialized service discovery module

    Raises:
        ValueError: if the service discovery module is not initialized
    """
    global _global_service_discovery
    if _global_service_discovery is None:
        raise ValueError("Service discovery module not initialized")

    return _global_service_discovery

if __name__ == "__main__":
    # Test the service discovery
    #k8s_sd = K8sServiceDiscovery("default", 8000, "release=test")
    InitializeServiceDiscovery(ServiceDiscoveryType.K8S, 
                               namespace = "default", 
                               port = 8000, 
                               label_selector = "release=test")

    k8s_sd = GetServiceDiscovery()
    import time
    time.sleep(1)
    while True:
        urls = k8s_sd.get_engine_urls()
        print(urls)
        time.sleep(2)