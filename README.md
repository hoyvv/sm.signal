---
layout: default
title: sm.signal Documentation
nav_order: 1
---

# sm.signal

A professional event system wrapper for Scrap Mechanic's `sm.message` API. It allows you to conveniently manage event subscriptions, handle debugging, and control data flows using a clean API design.

---

## Table of Contents
- [Installation](#installation)
- [API Reference](#api-reference)
- [Usage Examples](#usage-examples)

---

## Installation

Place the `signal.lua` file into your mod's directory and require it in your script:

```lua
local Signal = require("signal")

