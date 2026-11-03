// Standalone macOS 27 DockSwipe probe. Not linked into the driver.
// HID serialization adapted from joshuarli/iss (0BSD); see iss-LICENSE.txt.
#include <ApplicationServices/ApplicationServices.h>
#include <mach/mach_time.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <signal.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/sysctl.h>
#include "../../MacinTouch/DockSwipe.h"
static int motion = 1;
static bool native_hid = false;
static volatile sig_atomic_t interrupted = 0;
static void interrupt_handler(int sig) { (void)sig; interrupted = 1; }
static bool emit(int phase, double progress, double velocity, bool post) {
    CGEventRef e = native_hid ? MacinTouchCreateNativeDockGestureEvent(motion, phase, progress, velocity) : MacinTouchCreateDockGestureEvent(motion, phase, progress, velocity);
    if (!e) { fprintf(stderr, "Cannot serialize HID event\n"); return false; }
    // Check the fields survive the serialization round trip.
    if (!native_hid && (CGEventGetIntegerValueField(e, 123) != motion ||
        CGEventGetIntegerValueField(e, 132) != phase ||
        fabs(CGEventGetDoubleValueField(e, 124) - progress) > 0.00001)) {
        CFRelease(e); fprintf(stderr, "Event round-trip mismatch\n"); return false;
    }
    printf("phase=%d progress=%+.4f velocity=%+.3f %s\n", phase, progress, velocity,
           post ? "POST" : "dry-run");
    fflush(stdout);
    if (post) {
        CGEventPost(kCGSessionEventTap, e);
        CGEventRef companion = CGEventCreate(NULL);
        if (companion && !native_hid) {
            CGEventSetType(companion, (CGEventType)29);
            CGEventPost(kCGSessionEventTap, companion);
        }
        if (companion) CFRelease(companion);
    }
    CFRelease(e);
    return true;
}
static unsigned long long active_space(void) {
    typedef int (*Connection)(void);
    typedef uint64_t (*Space)(int);
    Connection connection = (Connection)dlsym(RTLD_DEFAULT, "CGSMainConnectionID");
    Space space = (Space)dlsym(RTLD_DEFAULT, "CGSGetActiveSpace");
    return connection && space ? space(connection()) : 0;
}
int main(int argc, char **argv) {
    bool post = false, cancel = false, invert = false;
    for (int i=1; i<argc; i++) {
        if (!strcmp(argv[i], "--post")) post=true;
        else if (!strcmp(argv[i], "--cancel")) cancel=true;
        else if (!strcmp(argv[i], "--invert")) invert=true;
        else if (!strcmp(argv[i], "--native-hid")) native_hid=true;
        else if (!strcmp(argv[i], "--pinch")) motion=3;
        else if (!strcmp(argv[i], "--vertical")) motion=2;
        else { fprintf(stderr,"Usage: %s [--post] [--cancel] [--invert] [--pinch|--vertical] [--native-hid]\n", argv[0]); return 2; }
    }
    char version[64] = {0};
    size_t version_size = sizeof(version);
    if (sysctlbyname("kern.osproductversion", version, &version_size, NULL, 0) != 0 || atoi(version) != 27) {
        fprintf(stderr, "This experimental HID layout is limited to macOS 27; detected %s\n", version); return 2;
    }
    if (post && !AXIsProcessTrusted()) {
        fprintf(stderr,"Accessibility permission required for this executable/host. No events posted.\n"); return 3;
    }
    signal(SIGINT, interrupt_handler); signal(SIGTERM, interrupt_handler);
    double direction = invert ? -1 : 1;
    unsigned long long before = active_space();
    printf("axis=%d space-before=%llu mode=%s (default: dry run)\n", motion, before, cancel?"cancel":"complete");
    // Native reference profile starts with actual displacement and carries the
    // last movement into exit speed, unlike the original zero-velocity baseline.
    const double travel = native_hid ? 1.5 : 1.0;
    const double step = direction * travel / 120.0;
    printf("backend=%s total=%+.2f exitVelocity=%+.3f\n", native_hid ? "native-iohid" : "serialized-baseline", direction * travel, native_hid ? step * 100 : 0);
    if (!emit(1, native_hid ? step : 0, 0, post)) return 1;
    double progress=0;
    for (int i=1; i<=120 && !interrupted; i++) {
        double t=(double)i/120;
        progress=direction*(cancel ? 0.35*sin(M_PI*t) : travel*t);
        if (!emit(2, progress, 0, post)) {
            emit(8, progress, 0, post); return 1;
        }
        if (post) usleep(16000);
    }
    if (!emit(cancel || interrupted ? 8 : 4, progress, native_hid && !cancel && !interrupted ? step * 100 : 0, post)) return 1;
    if (post) usleep(800000);
    printf("space-after=%llu (space query may lag; animation needs visual verification)\n", active_space());
    return interrupted ? 130 : 0;
}
