# El Rayo Peronizador

> *"Cuando el pueblo agota su paciencia, hace tronar el escarmiento."*
> — Juan Domingo Perón

Sintetizador granular para [monome norns](https://monome.org/norns/), pensado para tocar y deformar un sample fijo de la Marcha Peronista como si fuera un instrumento.

![platform](https://img.shields.io/badge/platform-norns-blue) ![engine](https://img.shields.io/badge/engine-Glut-orange)

---

## ✊ Qué hace

- Carga un sample fijo (`marcha_peronista.wav`) y lo convierte en un instrumento granular polifónico.
- Tocás notas por MIDI y cada una dispara un grano de audio con su propio pitch — podés hacer acordes.
- Tiene **4 voces de polifonía**, position/size/density controlables en vivo, reverse, random position automático, reverb, y sensibilidad a la velocidad de tu teclado MIDI.
- Soporte opcional para **monome Arc 4** (POS / SIZE / DENS / REVERB en los 4 anillos).
- Pantalla con forma de onda generada en vivo y cabezal de reproducción en tiempo real.

---

## 📦 Instalación

### Desde Maiden (recomendado)
En la consola de Maiden (`matron`), escribí:
```lua
;install https://github.com/Elektroneslibres/El_Rayo_Peronizador
```

### Manual
1. Copiá `El_Rayo_Peronizador.lua` a `~/dust/code/El_Rayo_Peronizador/`
2. Copiá `marcha_peronista.wav` a `~/dust/audio/`

> El sample de la Marcha Peronista viene incluido en este repositorio. Si preferís usar otro audio, simplemente reemplazá ese archivo manteniendo el mismo nombre — cualquier WAV mono a 48kHz funciona bien.

---

## 🎛️ Controles

### Encoders (Norns)
| Encoder | Función |
|---|---|
| E1 | Position — punto de lectura en el sample |
| E2 | Grain Size — duración de cada grano |
| E3 | Density — granos por segundo |

### Botones
| Botón | Función |
|---|---|
| K2 | Random Position (toggle) — salta a una posición aleatoria cada 0.6s mientras está activo |
| K3 | Reverse (toggle) — invierte la dirección de reproducción |

### MIDI
- **Note On/Off** — dispara/corta un grano por voz (hasta 4 notas simultáneas, podés tocar acordes)
- El pitch de cada nota se calcula relativo a A4 (nota 69 = pitch original del sample)
- La **velocity** de cada nota controla el volumen del grano, en 5 niveles
- **CC 1** → Position
- **CC 2** → Grain Size
- **CC 3** → Density
- El canal MIDI se configura en el menú de parámetros (PARAMS)

### monome Arc 4 (opcional)
| Ring | Función |
|---|---|
| 1 | Position |
| 2 | Grain Size |
| 3 | Density |
| 4 | Reverb Mix |

Si conectás un Arc, se detecta automáticamente al cargar el script.

---

## 🖥️ Pantalla

- Forma de onda generada visualmente, con la zona actualmente granulada resaltada.
- Cabezal de reproducción en tiempo real (se congela visualmente cuando no hay notas sonando, para ahorrar lectura innecesaria).
- Indicadores de estado para REVERSE y RANDOM POSITION cuando están activos.

---

## ⚙️ Requisitos

- monome norns (cualquier versión con engine `Glut` disponible)
- Engine **Glut** por [artfwo](https://github.com/artfwo/glut) — si no lo tenés instalado:
  ```lua
  ;install https://github.com/artfwo/glut
  ```
- Un sample propio nombrado `marcha_peronista.wav` (ver sección de instalación)
- MIDI controller (recomendado) para tocar el instrumento
- monome Arc 4 (opcional)

---

## 🙏 Créditos

Desarrollado por **elektrones_libres**

Engine granular: [Glut](https://github.com/artfwo/glut) por artfwo.

---

## 📜 Licencia

Compartilo, modificalo, usalo. Si lo mejorás, ¡mandá un pull request!
