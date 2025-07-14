#
# Installation of en-US for the Pico TTS engine in the system image
# 
# Include this file in a product makefile to include the language files for english US
#
# Note the destination path matches that used in external/svox/pico/tts/com_svox_picottsengine.cpp
# 

#PRODUCT_COPY_FILES += \
#	external/svox/pico/lang/en-US_lh0_sg.bin:system/tts/lang_pico/en-US_lh0_sg.bin \
#	external/svox/pico/lang/en-US_ta.bin:system/tts/lang_pico/en-US_ta.bin
LOCAL_PATH:= $(call my-dir)
LOCAL_POST_PROCESS_COMMAND := $(shell mkdir -p $(TARGET_OUT)/tts/lang_pico)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/en-US_lh0_sg.bin $(TARGET_OUT)/tts/lang_pico/)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/en-US_ta.bin $(TARGET_OUT)/tts/lang_pico/)
