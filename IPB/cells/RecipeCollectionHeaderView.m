//
//  RecipeCollectionHeaderView.m
//  CollectionViewDemo
//
//  Created by Simon on 22/1/13.
//  Copyright (c) 2013 Appcoda. All rights reserved.
//

#import "RecipeCollectionHeaderView.h"

@implementation RecipeCollectionHeaderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.title.font = [UIFont fontWithName:FONT_BOLD size:self.title.font.pointSize];
    }
    return self;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
