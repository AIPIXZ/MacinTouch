//
//  HIDSetup.h
//  MacinTouch
//
//  HID device setup and management for ILITEK touchscreen
//

#ifndef HIDSetup_h
#define HIDSetup_h

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDLib.h>

// HID Element structure
typedef struct HIDElement {
    IOHIDElementType    type;
    uint32_t            usagePage;
    uint32_t            usage;
    IOHIDElementCookie  cookie;
    CFIndex             currentValue;
    CFIndex             minValue;
    CFIndex             maxValue;
} HIDElement;

// HID Device data structure
typedef struct HIDDeviceData {
    io_object_t               notification;
    IOHIDDeviceInterface122** hidDeviceInterface;
    IOHIDQueueInterface**     hidQueueInterface;
    CFDictionaryRef           hidElementDictionary;
    CFRunLoopSourceRef        eventSource;
    SInt32                    minX;
    SInt32                    maxX;
    SInt32                    minY;
    SInt32                    maxY;
    UInt8                     buffer[256];
    bool                      isConnected;
} HIDDeviceData;

// Callback function type for HID element processing
typedef void (*HIDElementCallback)(HIDElement*);

// Function declarations
void InitHIDNotifications(SInt32 vendorID, SInt32 productID, HIDElementCallback callback);
void StopHIDNotifications(void);
void HIDDeviceAdded(void* context, IOReturn result, void* sender, IOHIDDeviceRef device);
void HIDDeviceRemoved(void* context, IOReturn result, void* sender, IOHIDDeviceRef device);
static void HIDInputValueCallback(void* context, IOReturn result, void* sender, IOHIDValueRef value);
void ProcessHIDElement(IOHIDElementRef element, IOHIDValueRef value, HIDElementCallback callback);

// Utility functions
void PrintHIDDeviceInfo(IOHIDDeviceRef device);
bool IsILITEKDevice(IOHIDDeviceRef device, SInt32 vendorID, SInt32 productID);
void LogHIDError(const char* function, IOReturn result);

#endif /* HIDSetup_h */