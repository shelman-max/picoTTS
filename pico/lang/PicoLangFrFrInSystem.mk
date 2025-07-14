#
# Installation of fr-FR for the Pico TTS engine in the system image
# 
# Include this file in a product makefile to include the language files for fr-FR
#
# Note the destination path matches that used in external/svox/pico/tts/com_svox_picottsengine.cpp
# 

#PRODUCT_COPY_FILES += \
#	external/svox/pico/lang/fr-FR_nk0_sg.bin:system/tts/lang_pico/fr-FR_nk0_sg.bin \
#	external/svox/pico/lang/fr-FR_ta.bin:system/tts/lang_pico/fr-FR_ta.bin
LOCAL_PATH:= $(call my-dir)
LOCAL_POST_PROCESS_COMMAND := $(shell mkdir -p $(TARGET_OUT)/tts/lang_pico)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/fr-FR_nk0_sg.bin $(TARGET_OUT)/tts/lang_pico/)
LOCAL_POST_PROCESS_COMMAND := $(shell cp $(LOCAL_PATH)/fr-FR_ta.bin $(TARGET_OUT)/tts/lang_pico/)
