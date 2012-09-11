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


#define SYNTAX				"oldiconutil {--help|[--inplace] <icnsFilePath>}"
#define SUMMARY				"Convert a .icns icon file holding PNG-encoded icons (supported\nin 10.6) to JPEG 2000-encoded icons (supported in 10.5)."
#define PARAMDESCRIPTIONS	"--help - Show this message.\n" \
							"icnsFilePath - Path of input icns file. Output file will have _10_5 appended to its name, unless the --inplace option is given, in which case it'll replace the input file.\n"


int main(int argc, const char * argv[])
{
	if( argc < 2 )
	{
		fprintf( stderr, "Error: Syntax is " SYNTAX );
		return 1;
	}
	
	BOOL	convertInPlace = NO;
	int		nameArgumentPosition = 1;
	
	if( strcasecmp( argv[1], "--help" ) == 0 )
	{
		printf( "Syntax: " SYNTAX "\n" SUMMARY "\n\n" PARAMDESCRIPTIONS "\n\n(c) 2012 by Elgato Systems GmbH, all rights reserved." );
		return 0;
	}
	else if( strcasecmp( argv[1], "--inplace" ) == 0 )
	{
		convertInPlace = YES;
		nameArgumentPosition ++;

		if( argc < (nameArgumentPosition +1) )
		{
			fprintf( stderr, "Error: Syntax is " SYNTAX );
			return 4;
		}
	}
	
	@autoreleasepool
	{
		NSString		*	inputPath = [NSString stringWithUTF8String: argv[nameArgumentPosition]];
		NSString		*	outputPath = convertInPlace ? inputPath : [[inputPath stringByDeletingPathExtension] stringByAppendingString: @"_10_5.icns"];
		BOOL				isDirectory = NO;
	    
		if( !inputPath || ![[NSFileManager defaultManager] fileExistsAtPath: inputPath isDirectory: &isDirectory] || isDirectory )
		{
			fprintf( stderr, "Error: Can't find input file." );
			return 2;
		}
		
		NSData			*	inputData = [NSData dataWithContentsOfFile: inputPath];
		if( !inputData )
		{
			fprintf( stderr, "Error: Can't load input file." );
			return 3;
		}
		
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
				
				printf( "Found block '%s'", blockType );
				
#if FILTER_TOC_OUT
				if( strcmp(blockType,"TOC ") == 0 )
				{
					uint32_t	blockSize = NSSwapInt( *(uint32_t*)(theBytes +currOffs) );
					printf( "\tSkipping %d (+4) bytes.", blockSize );
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
					uint32_t	startLong = *(uint32_t*)[currBlockData bytes];
					BOOL		shouldConvert = (startLong == 0x474E5089);	// PNG data starts with 'âPNG'.
					
					if( !shouldConvert || strcmp(blockType,"ic08") == 0 || strcmp(blockType,"ic10") == 0
					   || strcmp(blockType,"ic13") == 0|| strcmp(blockType,"ic09") == 0 || strcmp(blockType,"ic12") == 0
					   || strcmp(blockType,"ic07") == 0|| strcmp(blockType,"ic11") == 0 || strcmp(blockType,"ic14") == 0 )
						;
					else
						shouldConvert = NO;
					
#if JUST_PASS_THROUGH
					shouldConvert = NO;
#endif
					
					if( shouldConvert )
					{
						printf( "\tConverting PNG to JPEG 2000" );
						
						NSBitmapImageRep	*	theImage = [[NSBitmapImageRep alloc] initWithData: currBlockData];
						NSData				*	jp2Data = [theImage representationUsingType: NSJPEG2000FileType properties:
							[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] forKey:NSImageCompressionFactor]];
						uint32_t				newSize = NSSwapInt( (uint32_t) [jp2Data length] + 8 );
						[outputData appendBytes: &newSize length: 4];	// Write size.
						[outputData appendData: jp2Data];
					}
					else
					{
						printf( "\tCopying data verbatim." );
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
		 
		printf( "Writing out %ld bytes.", [outputData length] );
		[outputData writeToFile: outputPath atomically: NO];
	}
    return 0;
}

