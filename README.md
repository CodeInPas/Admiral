# ⚓ Admiral — Multi-Database Administration 

<img width="818" height="432" alt="image" src="https://github.com/user-attachments/assets/7b5b8f25-7245-4a3f-aaf8-9b66158136d1" />

[![Lazarus](https://img.shields.io/badge/Built%20with-Lazarus%20%2F%20FPC-blue.svg)](https://www.lazarus-ide.org/)
[![Database](https://img.shields.io/badge/Databases-MySQL%20%7C%20PostgreSQL%20%7C%20SQLite%20%7C%20MariaDB%20%7C%20Firebird-teal.svg)](#supported-databases)
[![AI Powered](https://img.shields.io/badge/AI%20Copilot-llama.cpp%20%7C%20Ollama-orange.svg)](#-local-ai-integration)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Admiral** is a lightweight, cross-platform, native Multi-DBMS desktop administration suite built with **Free Pascal** and **Lazarus IDE**. Designed for developers, database administrators, and GIS analysts, Admiral combines schema management, intelligent SQL authoring, spatial data plotting, visual ERD modeling, and local AI assistance into a single performant GUI tool without heavy web runtimes.

---

## 🌟 Key Features

### 🗄️ Multi-DBMS Connectivity & Security
* **Supported Engines:** Native connectivity for **SQLite**, **MySQL**, **MariaDB**, **PostgreSQL**, and **Firebird** via ZeosDBO.
* **SSH Tunneling:** Built-in SSH port forwarding for secure, encrypted remote database connections.
* **Connection Profile Manager:** Fast switching between local instances and cloud databases.

### 🗺️ Built-in Geospatial Map Viewer (`lazmapviewer`)
* **Auto-detect Coordinates:** Automatically parses Latitude and Longitude columns (`lat`, `lng`, `geom`, etc.) from query result sets.
* **Dynamic Marker Plotting:** Renders points directly on top of OpenStreetMap, OpenTopoMap, CyclOSM, and CartoDB tile layers.
* **Smart Auto-Fit Bounds:** Calculates bounding boxes and auto-adjusts zoom levels to frame all dataset points.

### 🤖 Local AI Assistant & SQL Copilot (OpenAI Compatible)
* **Private / Offline LLM Support:** Seamlessly connect to local inference runners (`llama.cpp` server, `Ollama`, `LM Studio`) with zero data leakage.
* **AI Diagnostics & Auto-Fix:** Analyzes runtime SQL syntax errors and suggests immediate corrections.
* **AI Query Optimizer & Explainer:** Refactors queries for execution speed and generates markdown documentation for complex joins/CTEs.

### ⚡ Intelligent SQL Editor & Workspaces
* **Context-Aware IntelliSense:** Instant autocomplete triggered by typing `.` or hotkeys, indexing table schemas, views, and columns on the fly.
* **Multi-Tab Execution:** Non-blocking query execution powered by dedicated background worker threads.
* **Visual Query Builder & Formatter:** Construct complex queries visually and auto-format SQL syntax in one click.
* **Explain Plan Visualizer:** Evaluates query bottlenecks and index efficiency.

### 📊 Data Analysis & Advanced Tooling
* **Visual Chart & BI:** Transform tabular query outputs into dynamic bar, line, and pie charts.
* **Schema Difference & Transfer:** Compare schemas across multiple connections and transfer tables safely.
* **Two-Way Visual ERD Modeler:** Generate canvas diagrams from active databases and reverse/forward engineer schemas.
* **Safe Mode Guardrails:** Prevents accidental catastrophic executions (`DROP`, unconditional `DELETE`/`UPDATE`) with confirmation dialogues.


---

## 🚀 Getting Started

### Prerequisites
* **Lazarus IDE** (v4.0 or later recommended)
* **Free Pascal Compiler (FPC)** (v3.2.2 or later)
* **Required Lazarus Packages (via Online Package Manager):**
  * `zeosdbo` (Zeos Database Objects)
  * `lazmapviewerpkg` (Map Viewer)
  * `synedit` (Standard Lazarus component)
  * `bgracontrols` & `bgrabitmappack`

### Building from Source

1. Clone the repository:
   ```bash
   git clone [https://github.com/your-username/admiral.git](https://github.com/your-username/admiral.git)
   cd admiral
---


