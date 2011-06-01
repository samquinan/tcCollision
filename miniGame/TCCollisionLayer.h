//
//  HelloWorldLayer.h
//  miniGame
//
//  Created by Sam Quinan on 5/12/11.
//  Copyright University of Chicago 2011. All rights reserved.
//

#import "cocos2d.h"

@class TCGame;

// HelloWorldLayer
@interface TCCollisionLayer : CCLayerColor
{
    // a placeholder for touch location that can be accessed by internal convenience methods
    CGPoint singleTapLocation;
    // holds last killed cell location -- chemokines can only be released where a cell has already been killed
    CGPoint chemokineReleaseCoords;
    // bool value ensures chemokines can only be released once for a given set of corrdinates
    BOOL chemokinesReleased;
    // bool value to ensure win/lose only called once.
    BOOL gameOver;
    // references for score labels that need to be updated 
    CCLabelBMFont *infectedLabel;
    CCLabelBMFont *totalLabel;
    // the actual game model representation
    TCGame *game;
    // count of the number of scoring cell deaths (killed by chemokine signaling is not scoring)
    int killed;
    // time of game beginning, used to determine total runtime of the game, which factors into score through the time bonus
    double timeBegin;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

// takes 2 CG points (cur and dst) and returns a normalized 2D vector (represented in memory as a CGPoint) pointing from the first (cur) to the second (dst)
-(CGPoint) getVectorFromPoint:(CGPoint) cur ToPoint:(CGPoint) dst;


// sprites and objects arrays represent a hack for determining which sprites correspond to which objects. Ideally, this would be done using a NSDictionary; however, CCSprite objects do not implement NSCopying protocols and so cannot be used in NSDictionaries. Instead, I'm just ensuring that the nth object in the sprite array is the sprite that corresponds to the nth object in the objects array through careful access... Optimal, no. Working, yes.
@property (nonatomic, retain) NSMutableArray *sprites;
@property (nonatomic, retain) NSMutableArray *objects;
// properties for maintianing access to the CD8 sprite and the BatchNode layer containing all the cell sprite objects (which allows them all to be grouped in the same OpenGL draw call and is more efficient)
@property (nonatomic, retain) CCSprite *CD8;
@property (nonatomic, retain) CCSpriteBatchNode *spriteSheet;

@end
