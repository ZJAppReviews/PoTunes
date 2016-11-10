//
//  PCMyMusicViewController.m
//  PoTunes
//
//  Created by Purchas on 15/9/9.
//  Copyright © 2015年 Purchas. All rights reserved.
//

#import "PCMyMusicViewController.h"
#import "AFNetworking.h"
#import "PCSong.h"
#import "PCDownloadViewController.h"
#import "Common.h"
#import "PCDownLoadedCell.h"
#import "PCDownloadingTableViewController.h"
#import "DBHelper.h"
#import "PCDownloadManager.h"

@interface PCMyMusicViewController()<PCDownloadingTableViewControllerDelegate, PCDownloadViewControllerDelegate>

/** 下载专辑 */
@property (nonatomic, strong) NSMutableArray *downloadAlbums;
/** 正在下载的歌曲 */
@property (nonatomic, strong) NSMutableArray *downloadingArray;

/** 下载op */
@property (nonatomic, strong) AFHTTPRequestOperation *op;
/** 数据库Queue */
@property(nonatomic,strong) FMDatabaseQueue *queue;

@property (nonatomic, strong) DBHelper *helper;


@end

@implementation PCMyMusicViewController


//- (FMDatabaseQueue *)queue {

//    if (_queue == nil) {
//        
//        //打开数据库        
//        DBHelper *helper = [DBHelper getSharedInstance];
//        
//        self.helper = helper;
//        
//        [helper inDatabase:^(FMDatabase *db) {
//            
//            
//            [db executeUpdate:@"CREATE TABLE IF NOT EXISTS t_downloading (id integer PRIMARY KEY, author text, title text, sourceURL text,indexPath integer,thumb text,album text,downloaded bool, identifier text);"];
//            
//            if (![db columnExists:@"identifier" inTableWithName:@"t_downloading"]) {
//                
//                NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD %@ text", @"t_downloading", @"identifier"];
//                
//                [db executeUpdate:sql];
//                
//            }
//            
//        }];
//        
//        _queue = helper.queue;
//    }
//    
//    return _queue;
//}

- (NSMutableArray *)downloadAlbums {
    
    if (_downloadAlbums == nil) {
        
        _downloadAlbums = [NSMutableArray array];
        
        //查询专辑名称并去掉重复
        NSString *distinct = [NSString stringWithFormat:@"SELECT distinct album FROM t_downloading;"];
        
        NSMutableArray *tempArray = [NSMutableArray array];

        
//        [self.queue inDatabase:^(FMDatabase *db) {
//            
//            FMResultSet *s = [db executeQuery:distinct];
//            
//            while (s.next) {
//
//                NSString *album = [s stringForColumn:@"album"];
//                
//                [tempArray addObject:album];
//            }
//            
//            _downloadAlbums = tempArray;
//            
//            [s close];
//            
//        }];
    }
    
    return _downloadAlbums;
}

- (NSMutableArray *)downloadingArray {
    
    if (_downloadingArray == nil) {
        
        _downloadingArray = [NSMutableArray array];
        
        //初始化正在下载歌曲数组
        
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE downloaded = 0;"];
        
        NSMutableArray *tempArray = [NSMutableArray array];
        
//        [self.queue inDatabase:^(FMDatabase *db) {
//            
//            FMResultSet *s = [db executeQuery:query];
//            
//            while (s.next) {
//                
//                NSString *identifier = [NSString stringWithFormat:@"%@ - %@", [s stringForColumn:@"author"], [s stringForColumn:@"title"]];
//                
//                [tempArray addObject:identifier];
//                
//            }
//            
//            _downloadingArray = tempArray;
//            
//            [s close];
//            
//        }];
    }
    return _downloadingArray;
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.tableView.backgroundColor = [UIColor blackColor];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    self.helper = [DBHelper getSharedInstance];

    /** 注册通知 */
    [self getNotification];
    
    //修复之前的下载文件名称
    [self repairFormerSongName];
    
}


#pragma mark - 获取通知
- (void)getNotification {
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
   
    [center addObserver:self selector:@selector(download:) name:@"download" object:nil];
    
    [center addObserver:self selector:@selector(fullAlbum:) name:@"fullAlbum" object:nil];
    

}

- (void)download:(NSNotification *)sender {
    
    //获取通知内容
    NSArray *songs = sender.userInfo[@"songs"];
    
    NSNumber *indexPath = sender.userInfo[@"indexPath"];
    
    NSString *identifier = sender.userInfo[@"identifier"];

    PCSong *song = songs[[indexPath integerValue]];
    
    //添加到下载队列 先处理带有单引号歌曲名称
    NSString *artist = [song.author stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    
    NSString *songName = [song.title stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    
    NSString *album = [sender.userInfo[@"title"] stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    
    NSString *sql = [NSString stringWithFormat: @"INSERT INTO t_downloading(author,title,sourceURL,indexPath,thumb,album,downloaded,identifier) VALUES('%@','%@','%@','%ld','%@','%@','0', '%@');",artist,songName,song.sourceURL,[indexPath integerValue],song.thumb,album,identifier];
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
//        [self.queue inDatabase:^(FMDatabase *db) {
//            
//            [db executeUpdate:sql];
//            
//        }];

    });
    
    [self.downloadingArray addObject:[NSString stringWithFormat:@"%@ - %@", song.author, song.title]];
    
    
    
    if (self.op == nil || self.op.isCancelled || self.op.isFinished || self.op.isPaused) {
        
        [self beginDownloadMusicWithURL:song.sourceURL identifier:identifier];

    }

    //初始化专辑表

    if ([self.downloadAlbums indexOfObject:song.album] != NSNotFound) return;
       
    [self.downloadAlbums addObject:sender.userInfo[@"title"]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.tableView reloadData];
        
    });
}

- (void)fullAlbum:(NSNotification *)sender {
    //获取通知内容
    
    NSMutableArray *songArray = sender.userInfo[@"songs"];
    
    NSString *album = sender.userInfo[@"title"];
    
    if ([self.downloadAlbums indexOfObject:album] == NSNotFound) {
        
        [self.downloadAlbums addObject:album];

        [self.tableView reloadData];
    }
    
    for (PCSong *song in songArray) {
        
        NSArray *urlComponent = [song.sourceURL componentsSeparatedByString:@"/"];
        
        NSInteger count = urlComponent.count;
        
        NSString *identifier = [NSString stringWithFormat:@"%@%@%@",urlComponent[count - 3], urlComponent[count - 2], urlComponent[count - 1]];
        
        NSString *newIdentifier = [NSString stringWithFormat:@"%@ - %@", song.author, song.title];
        
        [self.downloadingArray addObject:newIdentifier];
        
        //添加到下载队列 先处理带有单引号歌曲名称
        NSString *artist = [song.author stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        
        NSString *songName = [song.title stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        
        NSString *album = [sender.userInfo[@"title"] stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        
        NSString *sql = [NSString stringWithFormat:
                         @"INSERT INTO t_downloading(author,title,sourceURL,indexPath,thumb,album,downloaded,identifier) VALUES('%@','%@','%@','%ld','%@','%@','0', '%@');"
                         ,artist,songName,song.sourceURL,[song.position integerValue],song.thumb,album,identifier];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
//            [self.queue inDeferredTransaction:^(FMDatabase *db, BOOL *rollback) {
//                
//                [db executeUpdate:sql];
//                
//                
//            }];
					
            if (self.op == nil || self.op.isCancelled || self.op.isFinished || self.op.isPaused) {
                
                [self beginDownloadMusicWithURL:song.sourceURL identifier:identifier];
                
            }
        });
        
    }
}

- (void)beginDownloadMusicWithURL:(NSString *)url identifier:(NSString *)identifier {
    
    NSString *rootPath = [self dirDoc];
    
    //保存路径
    NSString *filePath = [rootPath stringByAppendingPathComponent:identifier];
    
    //初始化队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    NSURL *URL = [NSURL URLWithString:url];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    self.op = op;
    
    op.outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"identifier"] = identifier;
    
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE sourceURL = '%@';", url];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
//        [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//            
//            FMResultSet *s = [db executeQuery:query];
//            
//            if (s.next) {
//                
//                NSString *queryResult = [NSString stringWithFormat:@"%@ - %@", [s stringForColumn:@"author"], [s stringForColumn:@"title"]];
//                
//                for (int i = 0; i < self.downloadingArray.count; i++) {
//                    
//                    if ([queryResult isEqualToString:self.downloadingArray[i]]) {
//                        
//                        dict[@"index"] = [NSNumber numberWithInt:i];
//                        
//                    }
//                }
//            }
//            
//            [op setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
//                
//                double downloadProgress = totalBytesRead / (double)totalBytesExpectedToRead;
//                
//                int progress = downloadProgress * 100;
//                
//                if (progress % 10 == 0 || (int)progress == 1) {
//                    
//                    NSNotification *percent = [NSNotification notificationWithName:@"percent"
//                                                                            object:nil
//                                                                          userInfo:@{@"percent":@(downloadProgress),@"index":dict[@"index"]}];
//                    
//                    [[NSNotificationCenter defaultCenter] postNotification:percent];
//                    
//                }
//            }];
//            
//            [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
//                
//                //改变歌曲下载状态
//                
//                [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//                    
//                    [db executeUpdate:@"UPDATE t_downloading SET downloaded = 1 WHERE identifier = ?;", identifier];
//                    
//                }];
//                
//                //删除已下载完歌曲的identifier及相关信息
//                
//                NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE downloaded = 0;"];
//                
//                NSMutableArray *tempArray = [NSMutableArray array];
//                
//                [self.queue inDatabase:^(FMDatabase *db) {
//                    
//                    FMResultSet *s = [db executeQuery:query];
//                    
//                    while (s.next) {
//                        
//                        NSString *identifier = [NSString stringWithFormat:@"%@ - %@", [s stringForColumn:@"author"], [s stringForColumn:@"title"]];
//                        
//                        [tempArray addObject:identifier];
//                        
//                    }
//                    
//                    self.downloadingArray = tempArray;
//                    
//                    [s close];
//                    
//                }];
//                
//                //发送下载完成通知
//                
//                NSNotification *downloadComplete = [NSNotification notificationWithName:@"downloadComplete" object:nil userInfo:dict];
//                
//                [[NSNotificationCenter defaultCenter] postNotification:downloadComplete];
//                
//                if (self.downloadingArray.count > 0) {
//                    
//                    NSString *newIdentifier = self.downloadingArray[0];
//                    
//                    NSArray *splitArr = [newIdentifier componentsSeparatedByString:@" - "];
//                    
//                    NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE author = '%@' and title = '%@';", [splitArr[0] stringByReplacingOccurrencesOfString:@"'" withString:@"''"], [splitArr[1] stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
//                    
//                    [self.queue inDatabase:^(FMDatabase *db) {
//                        
//                        FMResultSet *s = [db executeQuery:query];
//                        
//                        if (s.next) {
//                            
//                            NSString *URLStr = [s stringForColumn:@"sourceURL"];
//                            
//                            NSString *newIdentifier = [s stringForColumn:@"identifier"];
//                            
//                            [self beginDownloadMusicWithURL:URLStr identifier:newIdentifier];
//                            
//                        }
//                        
//                        [s close];
//                        
//                    }];
//                    
//                    
//                }
//                
//            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//                
//                NSLog(@"%@",error);
//                
//            }];
//            
//            //开始下载
//            [queue addOperation:op];
//            
//            [s close];
//        }];

        
    });
    
}

#pragma mark - 移除通知
- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"download" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"fullAlbum" object:nil];

    
}

#pragma mark - 修复之前的下载文件名称
- (void)repairFormerSongName {
    
    NSUserDefaults *user = [NSUserDefaults standardUserDefaults];
    
    NSString *repaired = [user objectForKey:@"repaired"];
    
    if (![repaired isEqualToString:@"repaired"]) {
        
        NSString *query = @"SELECT * FROM t_downloading";
        
//        [self.queue inDatabase:^(FMDatabase *db) {
//            
//            [MBProgressHUD showMessage:@"数据升级中请稍候"];
//
//            
//            FMResultSet * s = [db executeQuery:query];
//            
//            NSFileManager *manager = [NSFileManager defaultManager];
//            
//            NSString *rootPath = [self dirDoc];
//            
//            while (s.next) {
//                
//                NSString *identifier = [s stringForColumn:@"identifier"];
//                
//                NSLog(@"%@", identifier);
//                
//                if (identifier == nil) {
//                    
//                    //修改数据库
//                    
//                    NSString *urlString = [s stringForColumn:@"sourceURL"];
//                    
//                    NSArray *urlComponent = [urlString componentsSeparatedByString:@"/"];
//                    
//                    NSInteger count = urlComponent.count;
//                    
//                    NSString *identifier = [NSString stringWithFormat:@"%@%@%@",urlComponent[count - 3], urlComponent[count - 2], urlComponent[count - 1]];
//                    
//                    NSString *identifierUpdate = [NSString stringWithFormat:@"UPDATE t_downloading SET identifier = '%@' WHERE sourceURL = '%@'" , identifier, urlString];
//                    
//                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                        
//                        [self.queue inDeferredTransaction:^(FMDatabase *db, BOOL *rollback) {
//                            
//                            [db executeUpdate:identifierUpdate];
//                            
//                        }];
//                    });
//                    
//                    //修改文件名
//                    
//                    NSString *author = [s stringForColumn:@"author"];
//                    
//                    NSString *title = [s stringForColumn:@"title"];
//                    
//                    NSString *filePath = [rootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ - %@.mp3",author,title]];
//                    
//                    NSString *realPath = [filePath stringByReplacingOccurrencesOfString:@" / " withString:@" "];
//                    
//                    if ([manager fileExistsAtPath:realPath]) {
//                        
//                        NSString *dstPath = [rootPath stringByAppendingPathComponent:identifier];
//                        
//                        BOOL yes = [manager moveItemAtPath:realPath toPath:dstPath error:nil];
//                        
//                        NSLog(@"%d", yes);
//                        
//                    }
//                    
//                }
//            }
//            
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                
//                [MBProgressHUD hideHUD];
//                
//                [MBProgressHUD showSuccess:@"数据升级完毕"];
//                
//            });
//            
//        }];
			
        [user setObject:@"repaired" forKey:@"repaired"];
    }
}
#pragma mark - 获取文件主路径
- (NSString *)dirDoc {
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
   
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    return documentsDirectory;
    
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 2;

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
   
    if (section == 0) {
    
        return 1;
        
    } else {
        
        return self.downloadAlbums.count;
    }
}

#pragma mark - UITableViewDelegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    PCDownLoadedCell *cell = [PCDownLoadedCell cellWithTableView:tableView];
    
    if (indexPath.section == 0) {
       
        cell.imageView.image = [UIImage imageNamed:@"noArtwork.jpg"];
        
        cell.textLabel.text = @"正在缓存";
        
    } else {
        
        NSString *album = self.downloadAlbums[indexPath.row];
        
        cell.textLabel.text = album;
        
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE album = '%@';",album];
        
//        [self.queue inDatabase:^(FMDatabase *db) {
//            
//            FMResultSet *s = [db executeQuery:query];
//            
//            if ([s next]) {
//                
//                NSString *URLStr = [s stringForColumn:@"thumb"];
//                
//                NSURL *URL = [NSURL URLWithString:URLStr];
//                
//                [cell.imageView sd_setImageWithURL:URL placeholderImage:[UIImage imageNamed:@"defaultCover"]];
//                
//            }
//            
//            [s close];
//
//        }];

        
    }
    
    cell.progressView.hidden = YES;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 66;
}
//跳转至已下载歌曲页面
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
   
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        
        PCDownloadViewController *download = [[PCDownloadViewController alloc] init];
        
        NSMutableArray *songArray = [NSMutableArray array];
        
        NSString *title = self.downloadAlbums[indexPath.row];
        
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE album = '%@' and downloaded = 1;",title];
        
//        [self.queue inDatabase:^(FMDatabase *db) {
//        
//            FMResultSet *s = [db executeQuery:query];
//
//            PCSongListTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
//            
//            NSString *album = [[cell.textLabel.text componentsSeparatedByString:@" – "] lastObject];
//            
//            while ([s next]) {
//                
//                PCSong *song = [[PCSong alloc] init];
//                
//                song.author = [s stringForColumn:@"author"];
//                
//                song.title = [s stringForColumn:@"title"];
//                
//                song.sourceURL = [s stringForColumn:@"sourceURL"];
//                
//                NSInteger index = [[s stringForColumn:@"indexPath"] integerValue];
//                
//                song.position = [NSNumber numberWithInteger:index];
//                
//                song.thumb = [s stringForColumn:@"thumb"];
//                
//                song.album = album;
//                
//                [songArray addObject:song];
//                
//            }
//            
//            [s close];
//        }];
        
        
        
        
        //根据歌曲序号进行排序
        
        download.songs = [self sort:songArray];
        
        download.delegate = self;
        
        [self.navigationController pushViewController:download animated:YES];
        
    } else {
        
        PCDownloadingTableViewController *downloading = [[PCDownloadingTableViewController alloc] init];
        
        if (self.op == nil || self.op.isPaused == 1) {
            
            downloading.paused = 1;

        } else {
            
            downloading.paused = 0;
        }
        
        downloading.delegate = self;
        
        downloading.downloadingArray = self.downloadingArray;
                
        [self.navigationController pushViewController:downloading animated:YES];
    }
}

/** 删除 */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
       
        return NO;
        
    } else {
   
        return YES;
        
    }
}
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    return @"你真要删呐？";
    
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSString *deleteAlbum = self.downloadAlbums[indexPath.row];
        
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE album = '%@';", deleteAlbum];
        
//        [self.queue inDatabase:^(FMDatabase *db) {
//            
//            FMResultSet *s = [db executeQuery:query];
//            
//            NSString *rootPath = [self dirDoc];
//            
//            NSFileManager *fileManager = [NSFileManager defaultManager];
//
//            while (s.next) {
//                
//                NSString *identifier = [s stringForColumn:@"identifier"];
//                
//                NSString *filePath = [rootPath  stringByAppendingPathComponent:identifier];
//                
//                if ([fileManager fileExistsAtPath:filePath]) {
//                    
//                    [fileManager removeItemAtPath:filePath error:nil];
//                    
//                }
//            }
//        }];
			
        NSString *delete = [NSString stringWithFormat:@"DELETE FROM t_downloading WHERE album = '%@';", deleteAlbum];
        
//        [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//            
//            [db executeUpdate:delete];
//
//        }];
        
        
        [self.downloadAlbums removeObjectAtIndex:indexPath.row];
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationTop];
        
        [tableView reloadData];
    }
}

//选择排序
- (NSMutableArray *)sort:(NSMutableArray *)arr {
    
    for (int i = 0; i < arr.count; i ++) {
        
        for (int j = i + 1; j < arr.count; j ++) {
        
            PCSong *foreSong = arr[i];
            
            PCSong *backSong = arr[j];
            
            if (foreSong.position > backSong.position) {
                
                arr[i] = backSong;
                
                arr[j] = foreSong;
            }
        }
    }
    
    return arr;
}

#pragma mark - PCDownloadingTableViewControllerDelegate
- (void)PCDownloadingTableViewController:(PCDownloadingTableViewController *)controller didClickThePauseButton:(UIButton *)button {
    
    if (self.op == nil) {
        
        NSString *identifier = self.downloadingArray[0];
        
        NSArray *splitArr = [identifier componentsSeparatedByString:@" - "];
        
        NSString *author = [splitArr[0] stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        
        NSString *title = [splitArr[1] stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
        
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE author = '%@' and title = '%@';", author, title];
        
//        [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//            
//            FMResultSet *s = [db executeQuery:query];
//            
//            if (s.next) {
//                
//                NSString *URLStr = [s stringForColumn:@"sourceURL"];
//                
//                NSString *newIdentifier = [s stringForColumn:@"identifier"];
//                
//                [self beginDownloadMusicWithURL:URLStr identifier:newIdentifier];
//                
//            }
//            
//            [s close];
//        }];
			
        return;
    }
    
    if (self.op.isPaused) {
        
        [self.op resume];
        
    } else {
        
        [self.op pause];
    
    }
}

- (void)PCDownloadingTableViewController:(PCDownloadingTableViewController *)controller didClickTheDeleteAllButton:(UIButton *)button {
    
    [self.op cancel];
    
    //删除本地文件
    NSString *select = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE downloaded = 0;"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *rootPath = [self dirDoc];
    
    
//    [self.queue inDatabase:^(FMDatabase *db) {
//       
//        FMResultSet *s = [db executeQuery:select];
//        
//        while (s.next) {
//            
//            NSString *identifier = [NSString stringWithFormat:@"%@",[s stringForColumn:@"identifier"]];
//            
//            NSString *filePath = [rootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", identifier]];
//            
//            [fileManager removeItemAtPath:filePath error:nil];
//            
//        }
//        
//        [s close];
//
//    }];
//    
	

    //删除数据库中未下载文件
    NSString *delete = [NSString stringWithFormat:@"DELETE FROM t_downloading WHERE downloaded = 0;"];
    
//    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//       
//        [db executeUpdate:delete];
//
//    }];
	
    //查询专辑名称并去掉重复
    NSString *distinct = [NSString stringWithFormat:@"SELECT distinct album FROM t_downloading;"];
    
    NSMutableArray *tempArray = [NSMutableArray array];
    
    
//    [self.queue inDatabase:^(FMDatabase *db) {
//        
//        FMResultSet *s = [db executeQuery:distinct];
//        
//        while (s.next) {
//            
//            NSString *album = [s stringForColumn:@"album"];
//            
//            [tempArray addObject:album];
//        }
//        
//        self.downloadAlbums = tempArray;
//        
//        [s close];
//    }];
	
    [self.downloadingArray removeAllObjects];
    
    [self.tableView reloadData];
    

}

#pragma mark - PCDownloadViewControllerDelegate

- (void)PCDownloadViewController:(PCDownloadViewController *)controller didDeletedSong:(PCSong *)song {
    
    NSString *author = [song.author stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    
    NSString *title = [song.title stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    
    NSString *album = [song.album stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
    
    NSString *delete = [NSString stringWithFormat:@"DELETE FROM t_downloading WHERE author = '%@' and title = '%@';", author, title];
    
//    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
//       
//        [db executeUpdate:delete];
//
//    }];
	
    
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM t_downloading WHERE album = '%@';",album];
    
//    [self.queue inDatabase:^(FMDatabase *db) {
//        
//        FMResultSet *s = [db executeQuery:query];
//        
//        if (!s.next) {
//            
//            for (int i = 0 ; i < self.downloadAlbums.count ; i++ ) {
//                
//                if ([song.album isEqualToString:self.downloadAlbums[i]]) {
//                    
//                    [self.downloadAlbums removeObjectAtIndex:i];
//                    
//                    dispatch_async(dispatch_get_main_queue(), ^{
//                        
//                        [self.tableView reloadData];
//                        
//                    });
//                    
//                    break;
//                }
//            }
//        }
//
//        [s close];
//
//    }];
    
}



@end
