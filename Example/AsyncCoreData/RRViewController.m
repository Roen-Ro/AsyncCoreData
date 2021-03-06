//
//  RRViewController.m
//  AsyncCoreData
//
//  Created by zxllf23@163.com on 01/12/2019.
//  Copyright (c) 2019 zxllf23@163.com. All rights reserved.
//

#import "RRViewController.h"
#import <AsyncCoreData/AsyncCoreData.h>
#import <AsyncCoreData/AycDataTransfer.h>
#import "PlaceModel.h"

#define PLACE_ENTITY @"PlaceEntity"

#define DB_PLACE QUERY_ENTITY(PLACE_ENTITY)

@interface RRViewController ()
@property (nonatomic, strong) AsyncCoreData *dbManager;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segControl;
@property (nonatomic, copy) NSString *SubFixStr;
@property (nonatomic, copy) NSArray *tmpCacheSpecialModels;
@end

@implementation RRViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
 //   self.segControl.selectedSegmentIndex = 1;
    [self dataStoreChange:self.segControl];
    [self initialDataMap];

}
-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
}

-(NSURL *)DataBaseFileForSegmentIndex:(NSUInteger)index {
    NSString *t = [self.segControl titleForSegmentAtIndex:index];
    NSURL *docUrl = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *fileUrl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",t]];
    return fileUrl;
}

-(void)initialDataMap {
    [AsyncCoreData setModelToDataBaseMapper:^(PlaceModel * model, NSManagedObject * _Nonnull managedObject) {
       // [managedObject setValue:model.uniqueValue forKey:@"uniqueID"]; //AsyncCoreData 自动设定
        [managedObject setValue:model.zipCode forKey:@"zip"];
        [managedObject setValue:model.uniqueValue forKey:@"name"];
        [managedObject setValue:model.country forKey:@"country"];
        [managedObject setValue:@(model.level) forKey:@"level"];
    } forEntity:PLACE_ENTITY];
    
    [AsyncCoreData setModelFromDataBaseMapper:^__kindof NSObject * _Nonnull(PlaceModel * _Nullable model, NSManagedObject * _Nonnull managedObject) {
        if(!model)
            model = [PlaceModel new];
       // model.uniqueValue = [managedObject valueForKey:@"uniqueID"];//不需要
        model.zipCode = [managedObject valueForKey:@"zip"];
        model.name = [managedObject valueForKey:@"name"];
        model.country = [managedObject valueForKey:@"country"];
        model.level = [[managedObject valueForKey:@"level"] intValue];
        
        return model;
    } forEntity:PLACE_ENTITY];
}

- (IBAction)dataStoreChange:(UISegmentedControl *)sender {
    
    NSURL *dataBaseFileUrl = [self DataBaseFileForSegmentIndex:sender.selectedSegmentIndex];
    self.SubFixStr = [self.segControl titleForSegmentAtIndex:self.segControl.selectedSegmentIndex];
    
    CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
    [AsyncCoreData setPersistantStore:dataBaseFileUrl withModel:@"RRCDModel"];
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    NSLog(@"Finished Set persistantStore at %@ in %.3f second",dataBaseFileUrl,t1-t0);
}

-(IBAction)moveDataBase:(UIButton *)sender {
    
    NSURL *curentURL = [self DataBaseFileForSegmentIndex:self.segControl.selectedSegmentIndex];
    NSUInteger idx = self.segControl.selectedSegmentIndex + 1;
    if(idx >= self.segControl.numberOfSegments ) {
        idx = 0;
    }
    NSURL *destURL = [self DataBaseFileForSegmentIndex:idx];
    
    NSError *e;
    [AycDataTransfer copyDataOfModel:@"RRCDModel" from:curentURL to:destURL error:&e];
    NSLog(@"Copy error: %@",e);
    
}

-(IBAction)changeToCurrentStore:(id)sender {
    [self dataStoreChange:self.segControl];
}



-(NSArray *)dataToWrite {
    
    PlaceModel *m1 = [PlaceModel new];
    m1.name = @"F-5";
    m1.country = @"Russia";
    m1.level = 5;
    m1.zipCode = [NSString stringWithFormat:@"%@-C001",self.SubFixStr];
    
    PlaceModel *m2 = [PlaceModel new];
    m2.name = @"F-4";
    m2.country = @"China";
    m2.level = 4;
    m2.zipCode = [NSString stringWithFormat:@"%@-C002",self.SubFixStr];
    
    PlaceModel *m3 = [PlaceModel new];
    m3.name = @"F-3";
    m3.country = @"FINNA";
    m3.level = 3;
    m3.zipCode = [NSString stringWithFormat:@"%@-C003",self.SubFixStr];
    
    PlaceModel *m4 = [PlaceModel new];
    m4.name = @"F-2";
    m4.country = @"British";
    m4.level = 2;
    m4.zipCode = [NSString stringWithFormat:@"%@-E001",self.SubFixStr];
    
    PlaceModel *m5 = [PlaceModel new];
    m5.name = @"F-1";
    m5.country = @"China";
    m5.level = 1;
    m5.zipCode = [NSString stringWithFormat:@"%@-A001",self.SubFixStr];
    
    PlaceModel *m6 = [PlaceModel new];
    m6.name = @"F-6";
    m6.country = @"Outter Space";
    m6.level = 6;
    m6.zipCode = nil;
    
    PlaceModel *m7 = [PlaceModel new];
    m7.name = @"F-7";
    m7.country = @"USA";
    m7.level = 2;
    m7.zipCode =  [NSString stringWithFormat:@"%@-C007",self.SubFixStr];
    
    self.tmpCacheSpecialModels = @[m1,m4];
    return @[m1,m2,m3,m4,m5,m7];
}

- (IBAction)writeData:(id)sender {
    
    NSError *e = [DB_PLACE saveModels:[self dataToWrite]];
    NSLog(@"writeData finished with error %@",e);
}

- (IBAction)readData:(id)sender {
    
    NSArray *results =  [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
    NSLog(@"readData:%@",results);
}


- (IBAction)writeDataAsync:(id)sender {

    [DB_PLACE saveModelsAsync:[self dataToWrite] completion:^(NSError *e) {
        NSLog(@"writeDataAsync finished with error %@",e);
    }];

}
- (IBAction)readDataAsync:(id)sender {
    
    [DB_PLACE modelsWithPredicateAsync:[NSPredicate predicateWithFormat:@"country = \"China\""] inRange:NSMakeRange(0, 999) sortByKey:nil reverse:NO completion:^(NSArray *results) {
        
        NSLog(@"readDataAsync:%@",results);
    }];

}
- (IBAction)readDataCustom:(UIButton *)sender {
    
    NSArray *list = [DB_PLACE keyPathes:@[@"name", @"country"] groupby:@[@"name", @"country"] withPredicate:nil sortKeyPath:@"level" inRange:NSMakeRange(0, NSUIntegerMax) reverse:false];
    NSLog(@"readDataCustom: %@", list);
}

//批量按条件更新
- (IBAction)batchConditonalUpdate:(id)sender {
    
    [DB_PLACE updateModelsWithPredicate:[NSPredicate predicateWithFormat:@"country = \"China\""] withValues:@[@(77),@"World"] forKeys:@[@"level",@"country"]];
    
    [self readDataCustom:nil];
}


- (IBAction)sort_reverse:(id)sender {
    
    NSRange rg = NSMakeRange(1, 3);
    NSLog(@"\n==================BY INSERT ORDER=======================\n");
    NSArray *allDatas = [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 11112) sortByKey:nil reverse:NO];
    NSLog(@"allDatas::%@",allDatas);
    
    NSArray *r1 = [DB_PLACE modelsWithPredicate:nil inRange:rg sortByKey:nil reverse:NO];
    NSLog(@"Range(1,3):%@",r1);
    
    NSArray *r2 = [DB_PLACE modelsWithPredicate:nil inRange:rg sortByKey:nil reverse:YES];
    NSLog(@"Range(1,3) reversed:%@",r2);
    
    NSLog(@"\n==================SORT BY 'level'=======================\n");
    allDatas = [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 111112) sortByKey:@"level" reverse:NO];
    NSLog(@"allDatas::%@",allDatas);
    
    r1 = [DB_PLACE modelsWithPredicate:nil inRange:rg sortByKey:@"level" reverse:NO];
    NSLog(@"Range(1,3):%@",r1);
    
    r2 = [DB_PLACE modelsWithPredicate:nil inRange:rg sortByKey:@"level" reverse:YES];
    NSLog(@"Range(1,3) reversed:%@",r2);
    
}

- (IBAction)multiThreadTest:(id)sender {
    
    PlaceModel *m1 = [PlaceModel new];
    m1.name = @"Dup柏林";
    m1.country = @"XXOO";
    m1.level = 1;
    m1.zipCode = [NSString stringWithFormat:@"%d",rand()%10];
    
    
    PlaceModel *m2 = [PlaceModel new];
    m2.name = @"Dup印度";
    m2.country = @"XXOO";
    m2.level = 1;
    m2.zipCode = [NSString stringWithFormat:@"%d",rand()%10];;
    
    [DB_PLACE saveModelsAsync:@[m1,m2] completion:^(NSError *e) {
        
        NSPredicate *p = [NSPredicate predicateWithFormat:@"country = \"XXOO\""];//[NSPredicate predicateWithFormat:@"country = \"WuGN\""];
        
        for(int i=0; i<100; i++) {
            
            NSArray *results =  [DB_PLACE modelsWithPredicate:p inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
            //   NSLog(@"readData:%@",results);
            
            background_async(^{
                for(PlaceModel *pm in results) {
                    PlaceModel *p1 =  [AsyncCoreData modelForStoreUrl:pm.StoreUrl];
                    PlaceModel *p2 =  [AsyncCoreData modelForStoreID:pm.storeID];
                    
                    NSLog(@"A- pm:%@ %p",p1,p2);
                }
            });
            
            [DB_PLACE modelsWithPredicateAsync:p inRange:NSMakeRange(0, 999) sortByKey:nil reverse:NO completion:^(NSArray *results) {
                
                //  NSLog(@"readDataAsync:%@",results);
                
                for(PlaceModel *pm in results) {
                    PlaceModel *p1 =  [AsyncCoreData modelForStoreUrl:pm.StoreUrl];
                    PlaceModel *p2 =  [AsyncCoreData modelForStoreID:pm.storeID];
                    
                    NSLog(@"B- pm:%@ %p",p1,p2);
                }
            }];
        }
        
    }];
    
}

- (IBAction)deleteSomemodels:(id)sender {
    NSLog(@"-----ALL MODELS-----");
    NSArray *results =  [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
    NSLog(@"%zu MODELS:%@",results.count,results);
    
    [DB_PLACE deleteModels:self.tmpCacheSpecialModels];
    results =  [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
    NSLog(@"-----AFTER DELETE CACHE MODELS %@-----",self.tmpCacheSpecialModels);
    NSLog(@"%zu MODELS:%@",results.count,results);
    
    NSString *specialZip = [NSString stringWithFormat:@"%@-A001",self.SubFixStr];
    PlaceModel *m = [PlaceModel new];
    m.zipCode = specialZip;
    [DB_PLACE deleteModels:@[m]];
    results =  [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
    NSLog(@"-----AFTER DELETE %@-----",specialZip);
    NSLog(@"%zu MODELS:%@",results.count,results);

//    [DB_PLACE deleteModelsWithPredicate:[NSPredicate predicateWithFormat:@"zipCode == nil"]];
//    results =  [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
//    NSLog(@"-----AFTER DELETE zip null (predicate)-----");
//    NSLog(@"%zu MODELS:%@",results.count,results);
    
    NSString *specialContry  = @"FINNA";
    [DB_PLACE deleteModelsWithPredicate:[NSPredicate predicateWithFormat:@"country = %@",specialContry]];
    results =  [DB_PLACE modelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:YES];
    NSLog(@"-----AFTER DELETE %@ (predicate)-----",specialContry);
    NSLog(@"%zu MODELS:%@",results.count,results);
}

- (IBAction)testConstraints:(id)sender  {
    
    PlaceModel *m = [PlaceModel new];
    m.name = @"ShengZhen";
    m.country = @"China";
    m.level = 1;
    m.zipCode = @"518000";
    NSError *e = [DB_PLACE saveModels:@[m]];
    NSLog(@"1------- saveError:%@",e);
    NSLog(@"A> m.storeID:%@",m.storeID);
    NSManagedObjectContext *ctx = [AsyncCoreData newContext];
    NSArray *dbs = [DB_PLACE dbModelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:nil inContext:ctx];
    for(NSManagedObject *o in dbs) {
        NSLog(@"o-1:%@",o);
    }
    
    PlaceModel *mcopy = [m copy];
    mcopy.name = @"BaoAn";
    mcopy.country = @"GuangDong";
    [DB_PLACE saveModels:@[mcopy]];
    NSLog(@"2------- saveError:%@",e);
    NSLog(@"B> mcopy.storeID:%@",mcopy.storeID);
    NSArray *dbs1 = [DB_PLACE dbModelsWithPredicate:nil inRange:NSMakeRange(0, 999) sortByKey:nil reverse:nil inContext:[AsyncCoreData newContext]];
    
    for(NSManagedObject *o in dbs1) {
        NSLog(@"o-2:%@",o);
    }
    NSLog(@"=========================");
    NSManagedObject *o1 = [AsyncCoreData DBModelForStoreID:m.storeID inContext:[AsyncCoreData newContext]];
    NSLog(@"o1:%@",o1);
    NSManagedObject *o2 = [AsyncCoreData DBModelForStoreID:mcopy.storeID inContext:[AsyncCoreData newContext]];
    NSLog(@"o2:%@",o2);
    
    
}

-(IBAction)clearAllData:(id)btn {
    
    for(int i=0; i<3;i++) {
        [AsyncCoreData invalidatePersistantSotre];
        NSError *error;
        NSString *name = [self.segControl titleForSegmentAtIndex:self.segControl.selectedSegmentIndex];
        NSURL *docUrl = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *dataBaseFileUrl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",name]];
        [[NSFileManager defaultManager] removeItemAtURL:dataBaseFileUrl error:&error];
        NSLog(@"Remove %@ error %@",[dataBaseFileUrl lastPathComponent],error);
        
        dataBaseFileUrl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite-shm",name]];
        [[NSFileManager defaultManager] removeItemAtURL:dataBaseFileUrl error:&error];
        NSLog(@"Remove %@ error %@",[dataBaseFileUrl lastPathComponent],error);
        
        dataBaseFileUrl = [docUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite-wal",name]];
        [[NSFileManager defaultManager] removeItemAtURL:dataBaseFileUrl error:&error];
        
        NSLog(@"Remove %@ error %@",[dataBaseFileUrl lastPathComponent],error);
    }
}

#define COUNT 1000

-(PlaceModel *)newPlaceModel {
    
    PlaceModel *m = [PlaceModel new];
    m.name = @"city test";
    m.country = @"British";
    m.level = 18;
    m.zipCode = nil;
    return m;
}



@end
