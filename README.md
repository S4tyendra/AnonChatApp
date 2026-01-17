# AnonChat

A Flutter-based anonymous chat application that connects random strangers for real-time conversations. Think of it as a modern take on Omegle, built with a focus on simplicity and privacy.

## What It Does

AnonChat pairs you with a random stranger from anywhere in the world for a one-on-one chat. There are no profiles, no friend lists, and no message history shared between sessions (unless you choose to save it locally). When you're done talking to someone, hit skip and you'll be matched with someone new.

## Features

- Anonymous matchmaking with strangers worldwide
- Real-time messaging with typing indicators
- Skip to next stranger (with a brief cooldown to prevent spam)
- Optional local chat history saving
- Export conversations as JSON files
- Dark mode interface
- Automatic reconnection handling

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **GetX** - State management and navigation
- **Dio** - HTTP client for API communication
- **Hive** - Local NoSQL storage for user data and chat history
- **Server-Sent Events** - Real-time message streaming

## Requirements

- Flutter SDK (Dart ^3.11.0 or later)
- Android Studio / Xcode for mobile builds

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/anonchatapp.git
   cd anonchatapp
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart              # App entry point and theme config
├── models/                # Data models (ChatMessage, ChatSession, UserData)
├── services/              # API and storage services
├── controllers/           # Business logic (auth, chat, settings)
├── pages/                 # UI screens
└── widgets/               # Reusable UI components
```

## How It Works

1. **Authentication** - Users authenticate through a web-based flow that generates a session token
2. **Connection** - The app establishes a Server-Sent Events stream with the backend
3. **Matchmaking** - The server pairs you with an available stranger
4. **Chatting** - Messages are sent via POST requests and received through the SSE stream
5. **Skipping** - Disconnect from current peer and get matched with someone new

## Building for Release

For Android:
```bash
flutter build apk --release
```

For iOS:
```bash
flutter build ios --release
```

## Backend Setup

The backend is also open source. If you want to host your own instance:

### Chat API Server

The main chat API backend is available at the same repository location. Clone and deploy it to your own server, then update the `baseUrl` in `lib/services/api_service.dart` to point to your instance.

The reference implementation runs at `https://anon-chatapi.devh.in`.

### Authentication Page

The authentication page is a simple HTML file with Cloudflare Turnstile captcha integration. To set up your own:

1. Visit the auth page and view source (Ctrl+U) to get the HTML
2. Replace the Cloudflare Turnstile site key with your own (get one from the Cloudflare dashboard)
3. Configure the secret API key in your backend to validate Turnstile responses
4. Host the HTML file and update the auth URL in `lib/controllers/auth_controller.dart`

The reference auth page runs at `https://create-anon-account.devh.in`.

## Configuration

To point the app to your own backend, update these files:

- `lib/services/api_service.dart` - Change `baseUrl` to your API server
- `lib/controllers/auth_controller.dart` - Change the auth page URL

## License

This project is provided as-is for educational purposes.
