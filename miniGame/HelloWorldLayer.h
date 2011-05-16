//
//  HelloWorldLayer.h
//  miniGame
//
//  Created by Sam Quinan on 5/12/11.
//  Copyright University of Chicago 2011. All rights reserved.
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"

// HelloWorldLayer
@interface HelloWorldLayer : CCLayerColor
{
    CGPoint singleTapLocation;
    CGPoint chemokineReleaseCoords;
    BOOL chemokinesReleased;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

@property (nonatomic, retain) NSMutableSet *sprites;
@property (nonatomic, retain) CCSprite *CD8;
@property (nonatomic, retain) CCSpriteBatchNode *spriteSheet;

@end
