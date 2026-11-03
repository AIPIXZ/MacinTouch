//
//  HIDSetup.c
//  MacinTouch
//
//  HID device setup and management implementation
//

#include "HIDSetup.h"
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <IOKit/hid/IOHIDElement.h>
#include <IOKit/hid/IOHIDValue.h>

// Global variables
static IOHIDManagerRef hidManager = NULL;
static HIDElementCallback globalCallback = NULL;
static SInt32 targetVendorID = 0;
static SInt32 targetProductID = 0;

// Initialize HID notifications and start device monitoring
void InitHIDNotifications(SInt32 vendorID, SInt32 productID, HIDElementCallback callback) {
    printf("🔍 Initializing HID notifications for ILITEK device (VID: 0x%04x, PID: 0x%04x)\n", 
           vendorID, productID);
    
    targetVendorID = vendorID;
    targetProductID = productID;
    globalCallback = callback;
    
    // Create HID Manager
    hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!hidManager) {
        printf("❌ Failed to create HID Manager\n");
        return;
    }
    
    // Set device matching criteria
    CFMutableDictionaryRef matchingDict = CFDictionaryCreateMutable(
        kCFAllocatorDefault, 0,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );
    
    if (matchingDict) {
        // Set vendor ID
        CFNumberRef vendorIDRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorID);
        if (vendorIDRef) {
            CFDictionarySetValue(matchingDict, CFSTR(kIOHIDVendorIDKey), vendorIDRef);
            CFRelease(vendorIDRef);
        }
        
        // Set product ID
        CFNumberRef productIDRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productID);
        if (productIDRef) {
            CFDictionarySetValue(matchingDict, CFSTR(kIOHIDProductIDKey), productIDRef);
            CFRelease(productIDRef);
        }
        
        // Set device matching
        IOHIDManagerSetDeviceMatching(hidManager, matchingDict);
        CFRelease(matchingDict);
    }
    
    // Register device callbacks
    IOHIDManagerRegisterDeviceMatchingCallback(hidManager, HIDDeviceAdded, NULL);
    IOHIDManagerRegisterDeviceRemovalCallback(hidManager, HIDDeviceRemoved, NULL);
    
    // Schedule with run loop
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    // Open the manager
    IOReturn result = IOHIDManagerOpen(hidManager, kIOHIDOptionsTypeNone);
    if (result != kIOReturnSuccess) {
        LogHIDError("IOHIDManagerOpen", result);
        return;
    }
    
    printf("✅ HID Manager initialized successfully\n");
}

// Tear down the HID manager — must be called before InitHIDNotifications can be called again
void StopHIDNotifications(void) {
    if (hidManager) {
        IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
        CFRelease(hidManager);
        hidManager = NULL;
    }
    globalCallback = NULL;
    printf("🛑 HID Manager stopped\n");
}

// Callback when HID device is added
void HIDDeviceAdded(void* context, IOReturn result, void* sender, IOHIDDeviceRef device) {
    printf("🔌 HID Device connected\n");
    
    if (!IsILITEKDevice(device, targetVendorID, targetProductID)) {
        printf("⚠️  Device is not target ILITEK device, ignoring\n");
        return;
    }
    
    PrintHIDDeviceInfo(device);
    
    // Register input value callback
    IOHIDDeviceRegisterInputValueCallback(device, HIDInputValueCallback, NULL);
    
    // Schedule device with run loop
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    // Open the device
    IOReturn openResult = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    if (openResult != kIOReturnSuccess) {
        LogHIDError("IOHIDDeviceOpen", openResult);
        return;
    }
    
    printf("✅ ILITEK device opened successfully\n");
}

// Callback when HID device is removed
void HIDDeviceRemoved(void* context, IOReturn result, void* sender, IOHIDDeviceRef device) {
    printf("🔌 HID Device disconnected\n");
    
    if (IsILITEKDevice(device, targetVendorID, targetProductID)) {
        printf("📱 ILITEK touchscreen disconnected\n");
        
        // Unschedule and close device
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
    }
}

// HID input value callback
static void HIDInputValueCallback(void* context, IOReturn result, void* sender, IOHIDValueRef value) {
    if (result != kIOReturnSuccess) {
        return;
    }
    
    IOHIDElementRef element = IOHIDValueGetElement(value);
    if (!element) {
        return;
    }
    
    ProcessHIDElement(element, value, globalCallback);
}

// Process HID element and convert to our structure
void ProcessHIDElement(IOHIDElementRef element, IOHIDValueRef value, HIDElementCallback callback) {
    if (!callback) {
        return;
    }
    
    HIDElement hidElement;
    
    // Fill element data
    hidElement.type = IOHIDElementGetType(element);
    hidElement.usagePage = IOHIDElementGetUsagePage(element);
    hidElement.usage = IOHIDElementGetUsage(element);
    hidElement.cookie = IOHIDElementGetCookie(element);
    hidElement.currentValue = IOHIDValueGetIntegerValue(value);
    hidElement.minValue = IOHIDElementGetLogicalMin(element);
    hidElement.maxValue = IOHIDElementGetLogicalMax(element);
    
    // Debug output for HID input (only for verbose debugging)
    // Uncomment the line below for detailed HID debugging
    // printf("🔍 HID Input - Page: %d, Usage: %d, Cookie: %d, Value: %ld\n", 
    //        hidElement.usagePage, hidElement.usage, hidElement.cookie, hidElement.currentValue);
    
    // Call Swift callback
    callback(&hidElement);
}

// Check if device is ILITEK device
bool IsILITEKDevice(IOHIDDeviceRef device, SInt32 vendorID, SInt32 productID) {
    CFNumberRef vendorIDRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    CFNumberRef productIDRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    
    if (!vendorIDRef || !productIDRef) {
        return false;
    }
    
    SInt32 deviceVendorID, deviceProductID;
    CFNumberGetValue(vendorIDRef, kCFNumberSInt32Type, &deviceVendorID);
    CFNumberGetValue(productIDRef, kCFNumberSInt32Type, &deviceProductID);
    
    return (deviceVendorID == vendorID && deviceProductID == productID);
}

// Print HID device information
void PrintHIDDeviceInfo(IOHIDDeviceRef device) {
    CFStringRef manufacturerRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
    CFStringRef productRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    CFNumberRef vendorIDRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    CFNumberRef productIDRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    CFNumberRef versionRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVersionNumberKey));
    
    printf("📱 Device Information:\n");
    
    if (manufacturerRef) {
        char manufacturer[256];
        CFStringGetCString(manufacturerRef, manufacturer, sizeof(manufacturer), kCFStringEncodingUTF8);
        printf("   Manufacturer: %s\n", manufacturer);
    }
    
    if (productRef) {
        char product[256];
        CFStringGetCString(productRef, product, sizeof(product), kCFStringEncodingUTF8);
        printf("   Product: %s\n", product);
    }
    
    if (vendorIDRef && productIDRef) {
        SInt32 vendorID, productID;
        CFNumberGetValue(vendorIDRef, kCFNumberSInt32Type, &vendorID);
        CFNumberGetValue(productIDRef, kCFNumberSInt32Type, &productID);
        printf("   VID: 0x%04x, PID: 0x%04x\n", vendorID, productID);
    }
    
    if (versionRef) {
        SInt32 version;
        CFNumberGetValue(versionRef, kCFNumberSInt32Type, &version);
        printf("   Version: %d.%02d\n", version >> 8, version & 0xFF);
    }
    
    printf("----------------------------------------\n");
}

// Log HID errors
void LogHIDError(const char* function, IOReturn result) {
    printf("❌ %s failed with error: 0x%08x\n", function, result);
    
    switch (result) {
        case kIOReturnNoDevice:
            printf("   Error: No device found\n");
            break;
        case kIOReturnNotOpen:
            printf("   Error: Device not open\n");
            break;
        case kIOReturnExclusiveAccess:
            printf("   Error: Exclusive access required\n");
            break;
        case kIOReturnBadArgument:
            printf("   Error: Bad argument\n");
            break;
        case kIOReturnUnsupported:
            printf("   Error: Unsupported operation\n");
            break;
        default:
            printf("   Error: Unknown error code\n");
            break;
    }
}