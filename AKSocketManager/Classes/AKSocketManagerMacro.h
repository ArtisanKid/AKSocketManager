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
        NSString *file = [NSString stringWithUTF8String:__FILE__].lastPathComponent;\
        NSLog((@"\n[%@][%d][%s]\n" _Format), file, __LINE__, __PRETTY_FUNCTION__, ## __VA_ARGS__);\
        printf("\n");\
    } while(0)
#else
    #define AKSocketManagerLog(_Format, ...)
#endif

#endif /* AKSocketManagerMacro_h */
