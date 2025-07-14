#
# Installation of en-GB for the Pico TTS engine in the system image
# 
# Include this file in a product makefile to include the language files for en-GB
#
# Note the destination path matches that used in external/svox/pico/tts/com_svox_picottsengine.cpp
# 

#PRODUCT_COPY_FILES += \
#	external/svox/pico/lang/en-GB_kh0_sg.bin:system/tts/lang_pico/en-GB_kh0_sg.bin \
#	external/svox/pico/lang/en-GB_ta.bin:system/tts/lang_pico/en-GB_ta.bin
LOCAL_PATH:= $(call my-dir)
LOCAL_POST_PROCESS_COMMAND := $(shell mkdir -p $(TARGET_OUT)/tts/lang_pico)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/en-GB_kh0_sg.bin $(TARGET_OUT)/tts/lang_pico/)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/en-GB_ta.bin $(TARGET_OUT)/tts/lang_pico/)
