//
//  SyncMutableDictionary.h
//  Runner
//
//  Created by zhuyuying on 2021/5/19.
//  Copyright © 2021 The Chromium Authors. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SyncMutableDictionary<KeyType, ObjectType> : NSDictionary<KeyType, ObjectType>

- (nullable id)objectForKey:(_Nonnull id)aKey;

- (nullable id)valueForKey:(_Nonnull id)aKey;

- (NSArray * _Nonnull)allKeys;

- (void)setObject:(nullable id)anObject forKey:(_Nonnull id <NSCopying>)aKey;

- (void)removeObjectForKey:(_Nonnull id)aKey;

- (void)removeAllObjects;

- (NSMutableDictionary *_Nonnull)getDictionary;

@end

NS_ASSUME_NONNULL_END
