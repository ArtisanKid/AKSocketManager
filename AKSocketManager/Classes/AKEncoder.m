//
//  AKEncoder.m
//  Pods
//
//  Created by 李翔宇 on 2017/6/15.
//
//

#import "AKEncoder.h"

@implementation AKEncoder

//关于Varint32编码可以参考http://www.cnblogs.com/tankaixiong/p/6366043.html

+ (NSData *)ak_writeRawVarint32:(NSUInteger)bodyLength {
    NSUInteger rawVarint32Size = 0;
    if ((bodyLength & (0xffffffff <<  7)) == 0) {
        rawVarint32Size = 1;
    } else if ((bodyLength & (0xffffffff << 14)) == 0) {
        rawVarint32Size = 2;
    } else if ((bodyLength & (0xffffffff << 21)) == 0) {
        rawVarint32Size = 3;
    } else if ((bodyLength & (0xffffffff << 28)) == 0) {
        rawVarint32Size = 4;
    } else {
        rawVarint32Size = 5;
    }
    
    Byte bytes[rawVarint32Size];
    for (NSUInteger i = 0; i < 5; i++) {
        if ((bodyLength & 128) == 0) {//是否小于127，小于则一个字节就可以表示了
            bytes[i] = bodyLength;
            break;
        } else {
            NSUInteger value = (bodyLength & 127) | 128;//因不于小127，加一高位标识
            bytes[i] = value;
            bodyLength = bodyLength >> 7;//右移7位，再递归
        }
    }
    
    return [NSData dataWithBytes:bytes length:rawVarint32Size];
}

+ (NSUInteger)ak_readRawVarint32:(NSData *)data byteCount:(NSUInteger *)count {
    /**
     Varint编码规则
     如果一个字节的第一位是1，表示后面的一个字节属于编码结果
     对于有符号字节来说，第一位是1表示负数
     */
    
    NSUInteger length = 0;
    for (NSUInteger i = 0; i < 5; i++) {//最多5字节
        if(data.length <= i) {
            return 0;
        }
        
        SignedByte byte = 0;
        [data getBytes:&byte range:NSMakeRange(i, 1)];
        length |= (byte & 127) << (7 * i);
        
        if (byte >= 0) {
            *count = i + 1;
            break;
        }
    }
    return length;
}

@end
