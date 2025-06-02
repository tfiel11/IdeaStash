# IdeaStash Watch Complication Setup Guide

## 🎯 What You'll Get
Your IdeaStash watch complication will show:
- **Quick idea count** - see how many ideas you've captured
- **Latest idea preview** - snippet of your most recent recording
- **One-tap recording** - tap the complication to instantly start recording
- **Multiple sizes** - works on all watch face complication slots

## 📋 Xcode Setup Steps

### 1. Add Files to Your Watch Target
I've created the complication file for you. Now you need to add it to your project:

1. **Open Xcode** and navigate to your project
2. **Right-click** on the "IdeaStash Watch App" folder in the navigator
3. **Select "Add Files to 'IdeaStash Watch App'"**
4. **Add the file**: `IdeaStashComplication.swift`
5. **Make sure** it's added to the **Watch App target** (not the main iOS app)

### 2. Configure URL Scheme
1. **Select your project** in the navigator
2. **Click on "IdeaStash Watch App"** target
3. **Go to the "Info" tab**
4. **Expand "URL Types"** section
5. **Click the "+" button** to add a new URL type
6. **Enter these details**:
   - **Identifier**: `com.yourcompany.ideastash.urlscheme`
   - **URL Schemes**: `ideastash`
   - **Role**: Editor

### 3. Enable Widget Extension Capability
1. **Stay in the "IdeaStash Watch App" target**
2. **Go to "Signing & Capabilities" tab**
3. **Click "+ Capability"**
4. **Add "WidgetKit Extension"** (if not already present)

### 4. Update Info.plist (Automatic)
Xcode should automatically add the widget configuration, but verify:
- The watch app's `Info.plist` should include widget extension entries
- If missing, add `NSExtension` entries for WidgetKit

### 5. Build and Test
1. **Build the watch app** (⌘+B)
2. **Run on watch simulator** or device
3. **Test the complication** by adding it to a watch face

## 🔧 Testing Your Complication

### Adding to Watch Face
1. **Long press** on the watch face
2. **Tap "Edit"**
3. **Swipe to complications**
4. **Tap a complication slot**
5. **Find "IdeaStash"** in the list
6. **Select it** and tap the Digital Crown

### Testing Deep Links
1. **Tap the complication** on the watch face
2. **The app should open** and automatically start recording
3. **Verify the complication updates** with new idea counts

## 🎨 Complication Features

### Available Styles
- **Circular**: Shows mic icon + idea count
- **Rectangular**: Shows count + latest idea preview + timestamp
- **Inline**: Shows "mic 5 ideas" format
- **Corner**: Compact mic icon + count

### Smart Updates
- **Refreshes every 15 minutes** automatically
- **Shows real-time idea count** from Core Data
- **Displays latest idea preview** with truncation
- **Handles empty state** gracefully

## 🔍 Troubleshooting

### Complication Not Appearing
- Ensure WidgetKit capability is added
- Check that `IdeaStashComplication.swift` is in the Watch App target
- Verify URL scheme is configured correctly
- Clean build folder (⌘+Shift+K) and rebuild

### Deep Link Not Working
- Confirm URL scheme `ideastash://record` is registered
- Check that `onOpenURL` handler is in place
- Verify notification handling in ContentView

### Data Not Showing
- Ensure Core Data context is properly shared
- Check that `StorageManager.shared` is accessible
- Verify `IdeaEntity` fetch requests work

## 🚀 What Happens After Setup

Once configured, users can:
1. **Add the complication** to any supported watch face
2. **See their idea count** at a glance
3. **Read latest idea previews** on rectangular complications
4. **Tap to instantly record** new ideas
5. **Get real-time updates** as they add more ideas

The complication follows Apple's Human Interface Guidelines and provides a premium, native experience that integrates seamlessly with watchOS!

## 📱 Next Steps
After the complication is working, consider:
- Testing on different watch faces
- Gathering user feedback on complication sizes
- Adding more deep link actions (e.g., view all ideas)
- Implementing Siri shortcuts for voice activation 