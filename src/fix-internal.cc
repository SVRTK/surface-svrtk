/*
* SVRTK : SVR reconstruction based on MIRTK
*
* Copyright 2018-2021 King's College London
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

// MIRTK
#include "mirtk/Common.h"
#include "mirtk/Options.h"
#include "mirtk/NumericsConfig.h"
#include "mirtk/IOConfig.h"
#include "mirtk/TransformationConfig.h"
#include "mirtk/RegistrationConfig.h"
#include "mirtk/GenericImage.h"
#include "mirtk/GenericRegistrationFilter.h"
#include "mirtk/Transformation.h"
#include "mirtk/HomogeneousTransformation.h"
#include "mirtk/RigidTransformation.h"
#include "mirtk/ImageReader.h"

using namespace std;
using namespace mirtk;

// =============================================================================
// Auxiliary functions
// =============================================================================

// -----------------------------------------------------------------------------

void usage()
{
    // cout << "Usage: mirtk threshold-image [input_image] [output_image] [threshold] \n" << endl;
    // cout << endl;
    // cout << "Function for binary thresholding: the output will be in [0; 1] range. "<< endl;
    cout << "\t" << endl;
    cout << "\t" << endl;

    exit(1);
}

// -----------------------------------------------------------------------------

// =============================================================================
// Main function
// =============================================================================

// -----------------------------------------------------------------------------

int main(int argc, char **argv)
{
    
    // cout << "---------------------------------------------------------------------" << endl;
    
    char buffer[256];
    RealImage stack;
    char * output_name = NULL;

    
    // //if not enough arguments print help
    // if (argc < 4)
    // usage();
    
    
    UniquePtr<ImageReader> image_reader;
    InitializeIOLibrary();
    
    
    //-------------------------------------------------------------------
    
    RealImage input_mask, output_mask;

    
    input_mask.Read(argv[1]);
    // cout<<"Input mask: "<<argv[1]<<endl;
    argc--;
    argv++;
    
    output_name = argv[1];
    // cout<<"Ouput mask: "<<output_name<<endl;
    argc--;
    argv++;
    
    
    // double threshold = 0;
    
    
    int cc_id = atoi(argv[1]);
    // cout<<"threshold : "<<threshold<<endl;
    argc--;
    argv++;

    int internal_id = atoi(argv[1]);
    // cout<<"threshold : "<<threshold<<endl;
    argc--;
    argv++;
    
    
    //-------------------------------------------------------------------
    

    int remove_id = 66;
    
    output_mask = input_mask;

    double y_max = -1000;
    double y_min = 1000;

    double z_max = -1000;
    double z_min = 1000;

    double ave_z = 0;
    double ave_n = 0;



    
        for (int z=0; z<output_mask.GetZ(); z++) {
            for (int y=0; y<output_mask.GetY(); y++) {
                for (int x=0; x<output_mask.GetX(); x++) {

                    if (input_mask(x,y,z) == cc_id) {
                        if (y < y_min) y_min = y; 
                        if (y > y_max) y_max = y;

                    }

                }
            }
        }

    double y_crop = y_max - (y_max - y_min)/8; 
    double y_ave = y_max - (y_max - y_min)/5; 


    for (int z=0; z<output_mask.GetZ(); z++) {
        for (int y=round(y_ave); y<(y_max+1); y++) {
            for (int x=0; x<output_mask.GetX(); x++) {

                if (input_mask(x,y,z) == cc_id) {
                    if (z < z_min) z_min = z;
                    if (z > z_max) z_max = z;
                }

            }
        }
    }

    double z_crop = z_max - 4*(z_max - z_min)/7; 


    // cout << y_crop << " : " << y_max << " " << y_min << endl;

    for (int z=0; z<output_mask.GetZ(); z++) {
        for (int y=0; y<output_mask.GetY(); y++) {
            for (int x=0; x<output_mask.GetX(); x++) {

                if (input_mask(x,y,z) == cc_id && y > y_crop) {

                    output_mask(x,y,z) = internal_id;
                }

                if (input_mask(x,y,z) == cc_id && y > y_ave && z < z_crop) {

                    output_mask(x,y,z) = internal_id;
                }


            }
        }
    }



    y_max = -1000;
    y_min = 1000;

    
    // for (int t=0; t<output_mask.GetT(); t++) {
        for (int z=0; z<output_mask.GetZ(); z++) {
            for (int y=0; y<output_mask.GetY(); y++) {
                for (int x=0; x<output_mask.GetX(); x++) {
    
                    if (output_mask(x,y,z) == cc_id) {
                        if (y < y_min) y_min = y; 
                        if (y > y_max) y_max = y;

                    }

                }
            }
        }

        y_min = y_min+1;
        y_max = y_max-1;


        for (int z=0; z<output_mask.GetZ(); z++) {
            for (int y=0; y<output_mask.GetY(); y++) {
                for (int x=0; x<output_mask.GetX(); x++) {
    
                    if (output_mask(x,y,z) == internal_id) {
                        if (y < y_min) output_mask(x,y,z) = remove_id;; 
                        if (y > y_max) output_mask(x,y,z) = remove_id;; 

                    }

                }
            }
        }




        //         for (int y=0; y<output_mask.GetY(); y++) {
        //     for (int x=0; x<output_mask.GetX(); x++) {

        //         int z_cc_max = -1000;

        //         for (int z=0; z<output_mask.GetZ(); z++) {

        //             if (output_mask(x,y,z) == cc_id) {
        //                 if (z > z_cc_max) z_cc_max = z;
        //             }

        //         }

        //         for (int z=0; z<output_mask.GetZ(); z++) {

        //             if (output_mask(x,y,z) == internal_id) {
        //                 if (z > z_cc_max) output_mask(x,y,z) = cc_id;
        //             }

        //         }

        //     }
        // }




    // }
                                     
    output_mask.Write(output_name);
    
    
    // cout << "---------------------------------------------------------------------" << endl;
    
    
    
    return 0;
}
