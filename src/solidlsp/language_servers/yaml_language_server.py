"""
Provides YAML specific instantiation of the LanguageServer class using yaml-language-server.
Contains various configurations and settings specific to YAML files.
"""

import logging
import os
import pathlib
import threading
from typing import Any

from solidlsp.language_servers.common import (
    RuntimeDependency,
    RuntimeDependencyCollection,
    get_bundled_npm_package_path,
    verify_node_npm_available,
)
from solidlsp.ls import SolidLanguageServer
from solidlsp.ls_config import LanguageServerConfig
from solidlsp.lsp_protocol_handler.lsp_types import InitializeParams
from solidlsp.lsp_protocol_handler.server import ProcessLaunchInfo
from solidlsp.settings import SolidLSPSettings

log = logging.getLogger(__name__)


class YamlLanguageServer(SolidLanguageServer):
    """
    Provides YAML specific instantiation of the LanguageServer class using yaml-language-server.
    Contains various configurations and settings specific to YAML files.
    """

    @staticmethod
    def _determine_log_level(line: str) -> int:
        """Classify yaml-language-server stderr output to avoid false-positive errors."""
        line_lower = line.lower()

        # Known informational messages from yaml-language-server that aren't critical errors
        if any(
            [
                "cannot find module" in line_lower and "package.json" in line_lower,  # Schema resolution - not critical
                "no parser" in line_lower,  # Parser messages - informational
            ]
        ):
            return logging.DEBUG

        return SolidLanguageServer._determine_log_level(line)

    def __init__(self, config: LanguageServerConfig, repository_root_path: str, solidlsp_settings: SolidLSPSettings):
        """
        Creates a YamlLanguageServer instance. This class is not meant to be instantiated directly.
        Use LanguageServer.create() instead.
        """
        yaml_lsp_executable_path = self._setup_runtime_dependencies(config, solidlsp_settings)
        super().__init__(
            config,
            repository_root_path,
            ProcessLaunchInfo(cmd=yaml_lsp_executable_path, cwd=repository_root_path),
            "yaml",
            solidlsp_settings,
        )
        self.server_ready = threading.Event()

    @classmethod
    def _setup_runtime_dependencies(cls, config: LanguageServerConfig, solidlsp_settings: SolidLSPSettings) -> str:
        """
        Setup runtime dependencies for YAML Language Server and return the command to start the server.

        This method supports both online (npm install) and offline (bundled) modes:
        1. First checks for bundled language server in standalone builds
        2. Falls back to checking locally installed version
        3. If not found and download is allowed, installs via npm
        """
        # 1. Check for bundled language server (for standalone/offline builds)
        bundled_path = get_bundled_npm_package_path(
            solidlsp_settings,
            package_dir_name="yaml-lsp",
            binary_name="yaml-language-server",
        )
        if bundled_path:
            log.info(f"Using bundled YAML Language Server at {bundled_path}")
            return f"{bundled_path} --stdio"

        # 2. Check for locally installed version
        yaml_ls_dir = os.path.join(cls.ls_resources_dir(solidlsp_settings), "yaml-lsp")
        yaml_executable_path = os.path.join(yaml_ls_dir, "node_modules", ".bin", "yaml-language-server")

        # Handle Windows executable extension
        if os.name == "nt":
            yaml_executable_path_cmd = yaml_executable_path + ".cmd"
            if os.path.exists(yaml_executable_path_cmd):
                return f"{yaml_executable_path_cmd} --stdio"
        elif os.path.exists(yaml_executable_path):
            return f"{yaml_executable_path} --stdio"

        # 3. Not found - need to install via npm
        # Check if download/install is allowed
        if not solidlsp_settings.allow_download_fallback:
            raise FileNotFoundError(
                f"YAML Language Server not found and download is disabled. "
                f"Expected at: {yaml_executable_path} or bundled at: {solidlsp_settings.bundled_ls_dir}"
            )

        # Verify node and npm are available (bundled or system)
        verify_node_npm_available(solidlsp_settings)

        deps = RuntimeDependencyCollection(
            [
                RuntimeDependency(
                    id="yaml-language-server",
                    description="yaml-language-server package (Red Hat)",
                    command="npm install --prefix ./ yaml-language-server@1.19.2",
                    platform_id="any",
                ),
            ]
        )

        log.info(f"YAML Language Server not found at {yaml_executable_path}. Installing...")
        deps.install(yaml_ls_dir)
        log.info("YAML language server dependencies installed successfully")

        # Handle Windows executable extension
        if os.name == "nt":
            yaml_executable_path = yaml_executable_path + ".cmd"

        if not os.path.exists(yaml_executable_path):
            raise FileNotFoundError(
                f"yaml-language-server executable not found at {yaml_executable_path}, something went wrong with the installation."
            )
        return f"{yaml_executable_path} --stdio"

    @staticmethod
    def _get_initialize_params(repository_absolute_path: str) -> InitializeParams:
        """
        Returns the initialize params for the YAML Language Server.
        """
        root_uri = pathlib.Path(repository_absolute_path).as_uri()
        initialize_params = {
            "locale": "en",
            "capabilities": {
                "textDocument": {
                    "synchronization": {"didSave": True, "dynamicRegistration": True},
                    "completion": {"dynamicRegistration": True, "completionItem": {"snippetSupport": True}},
                    "definition": {"dynamicRegistration": True},
                    "references": {"dynamicRegistration": True},
                    "documentSymbol": {
                        "dynamicRegistration": True,
                        "hierarchicalDocumentSymbolSupport": True,
                        "symbolKind": {"valueSet": list(range(1, 27))},
                    },
                    "hover": {"dynamicRegistration": True, "contentFormat": ["markdown", "plaintext"]},
                    "codeAction": {"dynamicRegistration": True},
                },
                "workspace": {
                    "workspaceFolders": True,
                    "didChangeConfiguration": {"dynamicRegistration": True},
                    "symbol": {"dynamicRegistration": True},
                },
            },
            "processId": os.getpid(),
            "rootPath": repository_absolute_path,
            "rootUri": root_uri,
            "workspaceFolders": [
                {
                    "uri": root_uri,
                    "name": os.path.basename(repository_absolute_path),
                }
            ],
            "initializationOptions": {
                "yaml": {
                    "schemaStore": {"enable": True, "url": "https://www.schemastore.org/api/json/catalog.json"},
                    "format": {"enable": True},
                    "validate": True,
                    "hover": True,
                    "completion": True,
                }
            },
        }
        return initialize_params  # type: ignore

    def _start_server(self) -> None:
        """
        Starts the YAML Language Server, waits for the server to be ready and yields the LanguageServer instance.
        """

        def register_capability_handler(params: Any) -> None:
            return

        def do_nothing(params: Any) -> None:
            return

        def window_log_message(msg: dict) -> None:
            log.info(f"LSP: window/logMessage: {msg}")

        self.server.on_request("client/registerCapability", register_capability_handler)
        self.server.on_notification("window/logMessage", window_log_message)
        self.server.on_notification("$/progress", do_nothing)
        self.server.on_notification("textDocument/publishDiagnostics", do_nothing)

        log.info("Starting YAML server process")
        self.server.start()
        initialize_params = self._get_initialize_params(self.repository_root_path)

        log.info("Sending initialize request from LSP client to LSP server and awaiting response")
        init_response = self.server.send.initialize(initialize_params)
        log.debug(f"Received initialize response from YAML server: {init_response}")

        # Verify document symbol support is available
        if "documentSymbolProvider" in init_response["capabilities"]:
            log.info("YAML server supports document symbols")
        else:
            log.warning("Warning: YAML server does not report document symbol support")

        self.server.notify.initialized({})

        # YAML language server is ready immediately after initialization
        log.info("YAML server initialization complete")
        self.server_ready.set()
        self.completions_available.set()
