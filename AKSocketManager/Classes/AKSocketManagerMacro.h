//
//  AKSocketManagerMacro.h
//  Pods
//
//  Created by 李翔宇 on 2017/4/23.
//
//

#ifndef AKSocketManagerMacro_h
#define AKSocketManagerMacro_h

#if DEBUG
    #define AKSocketManagerLog(_Format, ...)\
    do {\
        NSLog((@"\n[File:%s]\n[Line:%d]\n[Function:%s]\n" _Format), __FILE__, __LINE__, __PRETTY_FUNCTION__, ## __VA_ARGS__);\
        printf("\n");\
    } while(0)
#else
    #define AKSocketManagerLog(_Format, ...)
#endif

#endif /* AKSocketManagerMacro_h */
