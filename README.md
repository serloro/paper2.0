# Pap3rBlox 3.0

Un juego de conquista de territorio para Roblox inspirado en el clásico Paper.io.

## 🎮 Descripción

Pap3rBlox 3.0 es un juego multijugador donde los jugadores compiten por conquistar el mayor territorio posible mientras evitan bolas con pinchos y las líneas de otros jugadores.

## 🚀 Características

- **Sistema de territorio con grid**: Conquista territorio dibujando líneas y volviendo a tu zona
- **Bots con IA inteligente**: 3 niveles de agresividad con predicción de bolas
- **GamePasses**: VIP, Rainbow Trail, Golden Skin
- **Rankings automáticos**: Diarios (24h) y semanales (7 días) con reset automático
- **Lobby medieval**: Sala de espera temática con tienda y scoreboards

## 🛠️ Desarrollo

Generado con [Rojo](https://github.com/rojo-rbx/rojo) 7.6.1.

### Build

```bash
rojo build -o "paper2.0.rbxlx"
```

### Servidor de desarrollo

```bash
rojo serve
```

Para más ayuda, consulta [la documentación de Rojo](https://rojo.space/docs).

## 📁 Estructura

```
src/
├── client/          # Scripts del cliente
│   ├── character/   # Control del personaje
│   ├── gui/         # Interfaz de usuario
│   └── player/      # Lógica del jugador
├── server/          # Scripts del servidor
│   ├── LobbyManager # Gestión del lobby
│   ├── MatchController # Control de partidas
│   └── GamePassService # Sistema de compras
└── shared/          # Módulos compartidos
    ├── BotAI        # Inteligencia artificial
    ├── DataManager  # Datos y rankings
    └── TerritoryManager # Sistema de territorio
```
