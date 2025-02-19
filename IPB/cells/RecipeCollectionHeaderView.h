//
//  RecipeCollectionHeaderView.h
//  CollectionViewDemo
//
//  Created by Simon on 22/1/13.
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RecipeCollectionHeaderView : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;
@property (weak, nonatomic) IBOutlet UILabel *title;

@end
