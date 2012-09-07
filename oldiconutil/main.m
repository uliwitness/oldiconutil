//
//  main.m
//  oldiconutil
//
//  Created by Uli Kusterer on 9/5/12.
//  Copyright (c) 2012 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define JUST_PASS_THROUGH		0
#define FILTER_TOC_OUT			1


int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		NSString		*	inputPath = [NSString stringWithUTF8String: argv[1]];
		NSData			*	inputData = [NSData dataWithContentsOfFile: inputPath];
		NSMutableData	*	outputData = [NSMutableData dataWithLength: 0];
	    
		const char* theBytes = [inputData bytes];
		NSUInteger	currOffs = 4;	// Skip 'icns'
		uint32_t	fileSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
		currOffs += 4;
		
		while( currOffs < fileSize )
		{
			@autoreleasepool
			{
				char		blockType[5] = { 0 };
				memmove( blockType, theBytes +currOffs, 4 );
				currOffs += 4;
				
				NSLog( @"Found block '%s'", blockType );
				
#if FILTER_TOC_OUT
				if( strcmp(blockType,"TOC ") == 0 )
				{
					uint32_t	blockSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
					NSLog( @"\tSkipping %d (+4) bytes.", blockSize );
					currOffs += blockSize -4;
				}
				else
#endif
				{
					[outputData appendBytes: blockType length: 4];	// Copy the type.
					uint32_t	blockSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
					currOffs += 4;
					NSData	*	currBlockData = [NSData dataWithBytes: theBytes +currOffs length: blockSize -8];
					currOffs += blockSize -8;
					uint32_t		startLong = *(uint32_t*)[currBlockData bytes];
					bool			shouldConvert = startLong == 0x474E5089;
					
					if( !shouldConvert || strcmp(blockType,"ic08") == 0 || strcmp(blockType,"ic10") == 0
					   || strcmp(blockType,"ic13") == 0|| strcmp(blockType,"ic09") == 0 || strcmp(blockType,"ic12") == 0
					   || strcmp(blockType,"ic07") == 0|| strcmp(blockType,"ic11") == 0 || strcmp(blockType,"ic14") == 0 )
						;
					else
						shouldConvert = false;
					
#if JUST_PASS_THROUGH
					shouldConvert = false;
#endif
					
					if( shouldConvert )	// PNG file! '^aPNG'
					{
						NSLog( @"\tConverting PNG to JPEG 2000" );
						
						NSBitmapImageRep	*	theImage = [[NSBitmapImageRep alloc] initWithData: currBlockData];
						NSData				*	jp2Data = [theImage representationUsingType: NSJPEG2000FileType properties: [NSDictionary dictionary]];
						uint32_t				newSize = NSSwapInt( (uint32_t) [jp2Data length] ) +8;
						[outputData appendBytes: &newSize length: 4];	// Write size.
						[outputData appendData: jp2Data];
					}
					else
					{
						NSLog( @"\tCopying data verbatim." );
						blockSize = NSSwapInt( blockSize );
						[outputData appendBytes: &blockSize length: 4];	// Copy size.
						[outputData appendData: currBlockData];
					}
				}
			}
		}
		
		[outputData replaceBytesInRange: NSMakeRange(0,0) withBytes: "icns" length: 4];
		uint32_t theSize = NSSwapInt( (uint32_t)[outputData length] +4 );
		[outputData replaceBytesInRange: NSMakeRange(4,0) withBytes: &theSize length: 4];
		 
		NSLog( @"Writing out %ld bytes.", [outputData length] );
		[outputData writeToFile: [[inputPath stringByDeletingPathExtension] stringByAppendingString: @"_10_5.icns"] atomically: NO];
	}
    return 0;
}
