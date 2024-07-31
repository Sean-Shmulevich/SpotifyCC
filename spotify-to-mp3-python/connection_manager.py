from fastapi import WebSocket
from typing import Optional


class ConnectionManager:
    def __init__(self):
        self.lua_socket: Optional[WebSocket] = None
        self.js_socket: Optional[WebSocket] = None
        self.lua_width: int = 0
        self.lua_height: int = 0

    async def connect_js(self, websocket: WebSocket):
        await websocket.accept()
        self.js_socket = websocket

    async def connect_lua(self, websocket: WebSocket):
        await websocket.accept()
        self.lua_socket = websocket

    def js_connected(self):
        return self.js_socket is not None

    def lua_connected(self):
        return self.lua_socket is not None

    async def disconnect_js(self):
        self.js_socket = None

    def set_lua_monitor_size(self, size: list):
        self.lua_width = int(size[0])
        self.lua_height = int(size[1])

    async def disconnect_lua(self):
        self.lua_socket = None

    async def forward_to_lua(self, message: str):
        if self.lua_socket:
            await self.lua_socket.send_text(message)

    async def forward_to_js(self, message: str):
        if self.js_socket:
            await self.js_socket.send_text(message)
