/* Experimental per-game workaround; MIT licensed.
 * Forward other exports to a copy of the pinned Wine iphlpapi DLL.
 * Its DOS Wine-builtin marker is cleared to allow loading under a new name;
 * its executable code is unchanged. See compat/README.md.
 * Keep real IPv4 adapter identities, addresses and routing data unchanged.
 * This does not alter host interfaces, packets, or the game executable.
 */
#define WIN32_LEAN_AND_MEAN
#define _USE_32BIT_TIME_T
#define IPHLPAPI_DLL_LINKAGE
#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>
#include <stddef.h>

_Static_assert(sizeof(void *) == 4, "This workaround targets the 32-bit game only.");
_Static_assert(sizeof(IP_ADAPTER_INFO) == 640, "Must match Wine's 32-bit adapter ABI.");
_Static_assert(offsetof(IP_ADAPTER_INFO, Type) == 416, "Unexpected adapter layout.");

typedef ULONG (WINAPI *adapters_fn)(PIP_ADAPTER_INFO, PULONG);
static HMODULE self_module;
static INIT_ONCE initialized = INIT_ONCE_STATIC_INIT;
static adapters_fn original;
static DWORD load_error = ERROR_MOD_NOT_FOUND;

void *memcpy(void *dst, const void *src, size_t count) {
    volatile unsigned char *d = dst;
    const volatile unsigned char *s = src;
    while (count--) *d++ = *s++;
    return dst;
}
void *memset(void *dst, int value, size_t count) {
    volatile unsigned char *d = dst;
    while (count--) *d++ = (unsigned char)value;
    return dst;
}

static BOOL CALLBACK load_original(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    static const WCHAR name[] = L"royals_iphlpapi_wine.dll";
    WCHAR *path = HeapAlloc(GetProcessHeap(), 0, 32768 * sizeof(WCHAR));
    DWORD len;
    HMODULE module;
    (void)once; (void)parameter; (void)context;
    if (!path) { load_error = ERROR_NOT_ENOUGH_MEMORY; return TRUE; }
    len = GetModuleFileNameW(self_module, path, 32768);
    if (!len || len >= 32768) { load_error = ERROR_INSUFFICIENT_BUFFER; goto done; }
    while (len && path[len - 1] != L'\\' && path[len - 1] != L'/') len--;
    if (len + sizeof(name) / sizeof(WCHAR) > 32768) {
        load_error = ERROR_INSUFFICIENT_BUFFER; goto done;
    }
    memcpy(path + len, name, sizeof(name));
    module = LoadLibraryExW(path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!module) { load_error = GetLastError(); goto done; }
    original = (adapters_fn)GetProcAddress(module, "GetAdaptersInfo");
    load_error = original ? ERROR_SUCCESS : ERROR_PROC_NOT_FOUND;
done:
    HeapFree(GetProcessHeap(), 0, path);
    return TRUE;
}

/* The source is Wine's trusted result, but bound traversals defensively. */
static BOOL has_ipv4(const IP_ADAPTER_INFO *adapter) {
    const IP_ADDR_STRING *ip = &adapter->IpAddressList;
    unsigned int guard = 0;
    while (ip && guard++ < 4096) {
        const char *s = ip->IpAddress.String;
        if (s[0] && !(s[0]=='0' && s[1]=='.' && s[2]=='0' && s[3]=='.' &&
                     s[4]=='0' && s[5]=='.' && s[6]=='0' && s[7]==0)) return TRUE;
        ip = ip->Next;
    }
    return FALSE;
}

static BOOL add_list_size(const IP_ADDR_STRING *head, ULONG *bytes) {
    const IP_ADDR_STRING *item = head->Next;
    unsigned int guard = 0;
    while (item) {
        if (++guard > 4096 || *bytes > 16 * 1024 * 1024 - sizeof(*item)) return FALSE;
        *bytes += sizeof(*item);
        item = item->Next;
    }
    return TRUE;
}

static void copy_list(const IP_ADDR_STRING *src, IP_ADDR_STRING *dst,
                      IP_ADDR_STRING **extra, const IP_ADDR_STRING *old_current,
                      IP_ADDR_STRING **new_current) {
    while (src) {
        memcpy(dst, src, sizeof(*dst));
        if (src == old_current) *new_current = dst;
        if (src->Next) {
            dst->Next = (*extra)++;
            dst = dst->Next;
        } else dst->Next = NULL;
        src = src->Next;
    }
}

ULONG WINAPI GetAdaptersInfo(PIP_ADAPTER_INFO info, PULONG size) {
    IP_ADAPTER_INFO *all = NULL, *row, *out;
    IP_ADDR_STRING *extra;
    ULONG bytes = 0, capacity, required = 0, count = 0, status;
    unsigned int attempt, guard = 0;
    if (!size) return ERROR_INVALID_PARAMETER;
    InitOnceExecuteOnce(&initialized, load_original, NULL, NULL);
    if (!original) return load_error;
    status = original(NULL, &bytes);
    if (status != ERROR_BUFFER_OVERFLOW) return status;
    for (attempt = 0; attempt < 4; attempt++) {
        if (!bytes || bytes > 16 * 1024 * 1024) return ERROR_NOT_ENOUGH_MEMORY;
        all = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, bytes);
        if (!all) return ERROR_NOT_ENOUGH_MEMORY;
        status = original(all, &bytes);
        if (status != ERROR_BUFFER_OVERFLOW) break;
        HeapFree(GetProcessHeap(), 0, all); all = NULL;
    }
    if (status != ERROR_SUCCESS) goto done;
    for (row = all; row; row = row->Next) {
        if (++guard > 4096) { status = ERROR_INVALID_DATA; goto done; }
        if (!has_ipv4(row)) continue;
        count++;
        required += sizeof(*row);
        if (!add_list_size(&row->IpAddressList, &required) ||
            !add_list_size(&row->GatewayList, &required) ||
            !add_list_size(&row->DhcpServer, &required) ||
            !add_list_size(&row->PrimaryWinsServer, &required) ||
            !add_list_size(&row->SecondaryWinsServer, &required)) {
            status = ERROR_INVALID_DATA; goto done;
        }
    }
    if (!count) { status = ERROR_NO_DATA; goto done; }
    capacity = *size;
    *size = required;
    if (!info || capacity < required) { status = ERROR_BUFFER_OVERFLOW; goto done; }
    out = info;
    extra = (IP_ADDR_STRING *)(info + count);
    for (row = all; row; row = row->Next) {
        if (!has_ipv4(row)) continue;
        memcpy(out, row, sizeof(*out));
        out->Next = --count ? out + 1 : NULL;
        out->CurrentIpAddress = NULL;
        copy_list(&row->IpAddressList, &out->IpAddressList, &extra, row->CurrentIpAddress, &out->CurrentIpAddress);
        copy_list(&row->GatewayList, &out->GatewayList, &extra, row->CurrentIpAddress, &out->CurrentIpAddress);
        copy_list(&row->DhcpServer, &out->DhcpServer, &extra, row->CurrentIpAddress, &out->CurrentIpAddress);
        copy_list(&row->PrimaryWinsServer, &out->PrimaryWinsServer, &extra, row->CurrentIpAddress, &out->CurrentIpAddress);
        copy_list(&row->SecondaryWinsServer, &out->SecondaryWinsServer, &extra, row->CurrentIpAddress, &out->CurrentIpAddress);
        out++;
    }
done:
    if (all) HeapFree(GetProcessHeap(), 0, all);
    return status;
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        self_module = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}
