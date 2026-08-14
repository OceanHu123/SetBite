# SetBite食练记

Personal iOS app for **meal planning**, **macro/calorie tracking**, and **strength training** — built with SwiftUI and SwiftData.

> **Copyright © 2026 Oakley. All rights reserved.**  
> This repository is public for portfolio and learning reference only.  
> No license is granted for commercial use, redistribution, or derivative works without written permission.

## Features

- **Eat** — Recipe library, shopping list, AI recipe import (DeepSeek), meal calorie & macro logging
- **Train** — Workout plans, session logging, rest timer with Live Activity, progression charts, body metrics
- **Smart nutrition** — Brand food lookup via Open Food Facts, text/photo meal estimates, daily macro targets

## Tech Stack

- SwiftUI, SwiftData, HealthKit, ActivityKit (Dynamic Island)
- DeepSeek API (`deepseek-v4-flash`) for structured JSON tasks
- Open Food Facts API for packaged food nutrition

## Requirements

- Xcode 15+
- iOS 17+
- DeepSeek API key (enter in app Settings — never commit your key)

## Setup

1. Clone this repo
2. Open `RecipeKeeper.xcodeproj` in Xcode
3. Select your development team for signing
4. Run on device or simulator
5. Add your DeepSeek API key in **Settings**

## Third-Party Assets

- Muscle diagram atlas: [vulovix/body-muscles](https://github.com/vulovix/body-muscles) (Apache 2.0)

## Privacy

API keys and personal meal/workout data stay on your device (UserDefaults / SwiftData). Do not commit backups or `.env` files.
