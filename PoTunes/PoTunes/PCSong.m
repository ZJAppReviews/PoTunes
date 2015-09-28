//
//  PCSong.m
//  PoTunes
//
//  Created by Purchas on 15/9/10.
//  Copyright © 2015年 Purchas. All rights reserved.
//

#import "PCSong.h"

@implementation PCSong

+ (instancetype)songWithDict:(NSDictionary *)dict {
    return [[self alloc] initWithDict:dict];
}
- (instancetype)initWithDict:(NSDictionary *)dict {
    if (self = [super init]) {
        self.songName = dict[@"songName"];
        self.cover = dict[@"songCover"];
        self.artist = dict[@"artists"];
        self.album = dict[@"title"];
        self.URL = dict[@"songURL"];
        self.index = dict[@"indexPath"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.songName forKey:@"songName"];
    [aCoder encodeObject:self.cover forKey:@"cover"];
    [aCoder encodeObject:self.artist forKey:@"artist"];
    [aCoder encodeObject:self.album forKey:@"title"];
    [aCoder encodeObject:self.URL forKey:@"URL"];
    [aCoder encodeObject:self.index forKey:@"index"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.songName = [aDecoder decodeObjectForKey:@"songName"];
        self.cover = [aDecoder decodeObjectForKey:@"cover"];
        self.artist = [aDecoder decodeObjectForKey:@"artist"];
        self.album = [aDecoder decodeObjectForKey:@"title"];
        self.URL = [aDecoder decodeObjectForKey:@"URL"];
        self.index = [aDecoder decodeObjectForKey:@"index"];
    }
    return self;
}

@end
