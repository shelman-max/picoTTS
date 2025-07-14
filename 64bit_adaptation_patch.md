# PicoTTS 64位系统适配补丁

## 问题描述
在Android 15 (A15) 64位系统上，PicoTTS因为强制使用32位架构导致内存访问错误：
```
ABI: 'arm' (32位)
signal 11 (SIGSEGV), fault addr 0x6559d69c
picobase_get_next_utf8char+26
```

## 适配方案

### 1. 修改构建配置支持64位

#### 1.1 主应用配置 (pico/Android.mk)
```makefile
# 替换
LOCAL_MULTILIB := 32

# 修改为
LOCAL_MULTILIB := both
# 或者只支持64位
# LOCAL_MULTILIB := 64
```

#### 1.2 Native库配置 (pico/lib/Android.mk)
```makefile
# 替换
LOCAL_MULTILIB := 32

# 修改为  
LOCAL_MULTILIB := both
LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT
```

#### 1.3 JNI兼容层 (pico/compat/jni/Android.mk)
```makefile
# 替换
LOCAL_MULTILIB := 32

# 修改为
LOCAL_MULTILIB := both
```

#### 1.4 TTS引擎 (pico/tts/Android.mk)
```makefile
# 在两个构建规则中都替换
LOCAL_MULTILIB := 32

# 修改为
LOCAL_MULTILIB := both
```

### 2. 代码层面适配

#### 2.1 数据类型安全 (pico/lib/picobase.h)
添加64位兼容的类型定义：
```c
/* 64位系统适配 */
#ifdef PICO_64BIT_SUPPORT
    #include <stdint.h>
    typedef uint64_t picoos_ptr_t;
    typedef int64_t picoos_sptr_t;
#else
    typedef uint32_t picoos_ptr_t;
    typedef int32_t picoos_sptr_t;
#endif

/* 指针安全的转换宏 */
#define PICO_PTR_TO_UINT(ptr) ((picoos_ptr_t)(ptr))
#define PICO_UINT_TO_PTR(val) ((void*)(picoos_ptr_t)(val))
```

#### 2.2 内存对齐安全 (pico/lib/picobase.c)
在`picobase_get_next_utf8char`函数中添加对齐检查：
```c
picoos_uint8 picobase_get_next_utf8char(const picoos_uint8 *utf8s,
                                        const picoos_uint32 utf8slenmax,
                                        picoos_uint32 *pos,
                                        picobase_utf8char utf8char) {
    picoos_uint8 i;
    picoos_uint8 len;
    picoos_uint32 poscnt;

    /* 64位适配：增强输入验证 */
    if (utf8s == NULL || pos == NULL || utf8char == NULL) {
        if (utf8char != NULL) utf8char[0] = 0;
        return FALSE;
    }
    
    /* 64位适配：检查指针对齐 */
    #ifdef PICO_64BIT_SUPPORT
    if (((picoos_ptr_t)utf8s & 0x3) != 0) {
        /* 指针未对齐，可能在64位系统上有问题 */
        PICODBG_WARN(("UTF-8 buffer not aligned on 64-bit system"));
    }
    #endif
    
    /* 检查边界 */
    if (*pos >= utf8slenmax) {
        utf8char[0] = 0;
        return FALSE;
    }

    utf8char[0] = 0;
    len = picobase_det_utf8_length(utf8s[*pos]);
    
    /* 64位适配：增强长度检查 */
    if ((((*pos) + len) > utf8slenmax) ||
        (len > PICOBASE_UTF8_MAXLEN) ||
        (len == 0)) {
        return FALSE;
    }

    poscnt = *pos;
    i = 0;
    
    /* 64位适配：内存安全的字符复制 */
    while ((i < len) && (poscnt < utf8slenmax)) {
        /* 额外的边界检查 */
        if (poscnt >= utf8slenmax || i >= PICOBASE_UTF8_MAXLEN) {
            break;
        }
        utf8char[i] = utf8s[poscnt];
        poscnt++;
        i++;
    }
    
    utf8char[i] = 0;
    
    /* 检查是否成功完成字符解析 */
    if (i < len) {
        return FALSE;
    }
    
    *pos = poscnt;
    return TRUE;
}
```

#### 2.3 JNI层适配 (pico/compat/jni/com_android_tts_compat_SynthProxy.cpp)
添加64位JNI类型安全：
```cpp
// 在文件顶部添加
#ifdef PICO_64BIT_SUPPORT
    #define JLONG_TO_PTR(jlong_val) ((void*)(uintptr_t)(jlong_val))
    #define PTR_TO_JLONG(ptr) ((jlong)(uintptr_t)(ptr))
#else
    #define JLONG_TO_PTR(jlong_val) ((void*)(long)(jlong_val))
    #define PTR_TO_JLONG(ptr) ((jlong)(long)(ptr))
#endif
```

### 3. 调试支持

#### 3.1 添加64位调试标志
在所有Android.mk文件中添加：
```makefile
LOCAL_CFLAGS += -DPICO_ARCH_INFO
ifeq ($(TARGET_ARCH),arm64)
    LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_ARM64
endif
ifeq ($(TARGET_ARCH),x86_64)
    LOCAL_CFLAGS += -DPICO_64BIT_SUPPORT -DPICO_X86_64
endif
```

#### 3.2 运行时架构检测
在初始化代码中添加：
```c
void pico_arch_check(void) {
    #ifdef PICO_64BIT_SUPPORT
        PICODBG_INFO(("PicoTTS running in 64-bit mode"));
        PICODBG_INFO(("Pointer size: %zu bytes", sizeof(void*)));
    #else
        PICODBG_INFO(("PicoTTS running in 32-bit mode"));
    #endif
}
```

## 部署建议

### 渐进式部署
1. **阶段1**: 使用`LOCAL_MULTILIB := both`支持32/64位共存
2. **阶段2**: 测试64位版本稳定性
3. **阶段3**: 考虑迁移到纯64位`LOCAL_MULTILIB := 64`

### 测试验证
```bash
# 检查构建的架构
file pico/libs/arm64-v8a/libttspico.so
file pico/libs/armeabi-v7a/libttspico.so

# 运行时检查
adb logcat | grep "PicoTTS.*bit"
```

## 风险评估

**低风险**:
- 使用`both`配置保持向后兼容
- 代码修改为防御性编程
- 不影响现有32位设备

**中等风险**:
- 需要全面测试64位环境
- 内存使用略有增加
- 可能需要调整性能参数

## 预期效果

- 解决Android 15上的SIGSEGV崩溃
- 提供更好的64位系统兼容性
- 保持32位设备的向后兼容
- 提升整体稳定性