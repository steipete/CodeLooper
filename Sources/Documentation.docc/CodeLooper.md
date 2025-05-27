# ``CodeLooper``

An intelligent monitoring system for Cursor AI that automatically detects and resolves common issues.

## Overview

CodeLooper continuously monitors your Cursor AI sessions, automatically detecting and resolving connection issues, stuck states, and other common problems that can interrupt your workflow.

### Key Features

- **Intelligent Monitoring**: Real-time detection of Cursor AI issues
- **Automatic Recovery**: Resolves common problems without user intervention
- **Configurable Rules**: Customize monitoring behavior and intervention strategies
- **Session Logging**: Detailed logs for troubleshooting and analysis
- **Native macOS Integration**: Built specifically for macOS with proper permissions handling

### How It Works

CodeLooper uses advanced accessibility APIs to monitor Cursor AI windows and detect problematic states. When issues are detected, it applies targeted interventions to restore normal operation.

## Topics

### Core Components

- ``CursorMonitor``
- ``CursorInterventionEngine``
- ``CursorInstanceStateManager``

### Models

- ``MonitoredInstance``
- ``MonitoredInstanceInfo``
- ``CursorInstanceModels``

### Utilities

- ``LocatorManager``
- ``ElementHeuristic``
- ``Debouncer``

### Application

- ``AppDelegate``
- ``WindowManager``
- ``SettingsService``

### Diagnostics

- ``Logger``
- ``SessionLogger``
- ``LogCategory``
- ``LogLevel``