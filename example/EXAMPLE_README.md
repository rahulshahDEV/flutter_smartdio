# SmartDio Example App

This is a comprehensive Flutter example app that demonstrates all the features of the Flutter SmartDio package.

## 🚀 Features Demonstrated

### 🔘 **Test Buttons**
- **🚀 Basic GET** - Simple GET request with error handling
- **📝 Basic POST** - POST request with JSON body
- **🔄 Test Retry** - Retry mechanism with exponential backoff
- **💾 Test Cache** - Cache functionality (network-first strategy)
- **📴 Offline Queue** - Request queuing when offline
- **🔄 Deduplication** - Request deduplication testing
- **🎯 Type Safety** - Type-safe response transformation
- **🗑️ Clear Logs** - Clear the log display

### 📊 **Real-time Monitoring**
- **Live Logs** - Real-time request/response logging with color coding
- **Queue Status** - Shows current queue size in status bar
- **Connectivity Indicator** - Shows online/offline status
- **Performance Metrics** - Tap the analytics icon to view detailed metrics

### 🎛️ **Controls**
- **Analytics Button** (📊) - Shows performance metrics dialog
- **WiFi Toggle Button** - Manually toggle offline/online mode

## 🏃‍♂️ How to Run

### Prerequisites
- Flutter SDK installed
- An emulator or physical device connected

### Steps
1. Navigate to the example directory:
   ```bash
   cd flutter_smartdio/example
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## 🎯 Testing Guide

### 1. **Basic Functionality**
- Tap "🚀 Basic GET" to test a simple HTTP GET request
- Tap "📝 Basic POST" to test a POST request with JSON body
- Watch the logs for real-time feedback

### 2. **Retry Mechanism**
- Tap "🔄 Test Retry" to test the retry functionality
- This intentionally calls an endpoint that returns 500 status
- Watch the logs to see retry attempts with exponential backoff

### 3. **Caching**
- Tap "💾 Test Cache" twice in quick succession
- The first request will be from network (cache miss)
- The second request will be from cache (cache hit)
- Check the logs to see "From cache: true/false"

### 4. **Offline Queue**
- Tap "📴 Offline Queue" to test offline functionality
- This will:
  - Enable offline mode
  - Make a POST request (which gets queued)
  - Show queue size
  - Re-enable online mode
- Watch the status bar for queue count changes

### 5. **Request Deduplication**
- Tap "🔄 Deduplication" to test duplicate request prevention
- This sends two identical requests simultaneously
- One should be processed, the other deduplicated

### 6. **Type Safety**
- Tap "🎯 Type Safety" to test type-safe response handling
- This demonstrates transforming JSON to a custom `User` model
- Shows how the package maintains type safety throughout

### 7. **Performance Metrics**
- Tap the analytics icon (📊) in the app bar
- View detailed metrics including:
  - Cache hit/miss rates
  - Queue statistics
  - Overall success rates
  - Average response times
  - Connectivity status

### 8. **Manual Offline Mode**
- Tap the WiFi icon to manually toggle offline mode
- In offline mode, POST requests will be queued
- Queue size will show in the status bar
- Toggle back online to process queued requests

## 📱 UI Components

### Status Bar
- **WiFi Icon** - Shows connectivity status (🟢 online / 🔴 offline)
- **Queue Count** - Shows number of queued requests
- **Log Count** - Shows total number of log entries

### Live Logs
- **Color Coded** - Different colors for different log types:
  - 🟢 Green - Success messages
  - 🔴 Red - Error messages  
  - 🔵 Blue - Metrics/stats
  - 🟡 Yellow - Starting operations
  - ⚪ White - General info
- **Auto-scroll** - Automatically scrolls to latest log entry
- **Timestamps** - Each log entry includes a timestamp

## 🧪 What to Expect

### Successful Tests
- GET/POST requests should work (unless blocked by network policies)
- Cache should show hit/miss behavior
- Offline queue should store requests when offline
- Type safety should properly transform responses
- Metrics should accumulate over time

### Expected "Failures"
- **Retry Test** - Intentionally fails to demonstrate retry logic
- **Network Issues** - Some endpoints might be blocked by firewalls
- **Connectivity** - Initial connectivity check might take time

## 💡 Tips for Testing

1. **Network Connectivity** - The app uses real HTTP endpoints, so network connectivity is required for most tests
2. **Cloudflare Protection** - Some endpoints might be protected by Cloudflare, causing 403 errors (this is expected)
3. **Emulator vs Device** - Network behavior might differ between emulators and real devices
4. **Log Analysis** - Pay attention to the logs for detailed information about what's happening
5. **Metrics Dialog** - Use the metrics dialog to understand performance characteristics

## 🐛 Troubleshooting

### Common Issues
- **Network Errors** - Check internet connectivity
- **403 Errors** - Some endpoints are protected by Cloudflare
- **Timeout Errors** - Network might be slow, this is expected
- **Queue Not Processing** - Make sure to toggle back to online mode

### Debug Information
- All SmartDio operations are logged in real-time
- Check the live logs for detailed error information
- Use the metrics dialog for performance insights
- Queue events are logged as they happen

## 🎓 Learning Objectives

By using this example app, you'll learn:
- How to integrate SmartDio into a Flutter app
- How different SmartDio features work in practice
- How to handle success/error cases gracefully
- How to monitor and debug HTTP operations
- How to implement offline-first functionality
- How to use type-safe response transformations
- How to configure retry policies and caching strategies

## 📚 Next Steps

After testing the example app:
1. Check out the main package documentation
2. Look at the source code in `lib/main.dart`
3. Experiment with different configurations
4. Try implementing SmartDio in your own Flutter apps

Happy testing! 🚀