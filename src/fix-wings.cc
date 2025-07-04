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
    
    RealImage input_mask, output_mask, org_mask, cc_mask, internal_mask;

    
    input_mask.Read(argv[1]);
    // cout<<"Input mask: "<<argv[1]<<endl;
    argc--;
    argv++;

    org_mask.Read(argv[1]);
    // cout<<"Input mask: "<<argv[1]<<endl;
    argc--;
    argv++;

    cc_mask.Read(argv[1]);
    // cout<<"Input mask: "<<argv[1]<<endl;
    argc--;
    argv++;

    internal_mask.Read(argv[1]);
    // cout<<"Input mask: "<<argv[1]<<endl;
    argc--;
    argv++;
    
    output_name = argv[1];
    // cout<<"Ouput mask: "<<output_name<<endl;
    argc--;
    argv++;
    
    
    // double threshold = 0;
    
    
    // int cc_id = atoi(argv[1]);
    // // cout<<"threshold : "<<threshold<<endl;
    // argc--;
    // argv++;

    // int internal_id = atoi(argv[1]);
    // // cout<<"threshold : "<<threshold<<endl;
    // argc--;
    // argv++;
    
    int cc_id = 20;
    int internal_id = 23;
    int third_roi = 18;
    int cavum_roi = 9;


    //-------------------------------------------------------------------
    

    int remove_id = 66;
    
    output_mask = input_mask;

    double y_max = -1000;
    double y_min = 1000;

    double z_max = -1000;
    double z_min = 1000;

    double ave_x = 0;
    double ave_n = 0;

    Array<double> all_ave_x;

    double cc_y_max = -1000;


    double bs_y_max = -1000;

    
    // for (int t=0; t<output_mask.GetT(); t++) {
        for (int y=0; y<output_mask.GetY(); y++) { 
            
            ave_x = 0;
            ave_n = 0;

            
            for (int z=0; z<output_mask.GetZ(); z++) {
                for (int x=0; x<output_mask.GetX(); x++) {
    
                    if (internal_mask(x,y,z) > 0) {
                        ave_x = ave_x + x;
                        ave_n = ave_n + 1;

                        if (y > y_max) y_max = y;
                        if (y < y_min) y_min = y;

                        if (z > z_max) z_max = z;
                        if (z < z_min) z_min = z;

                    }

                    if (input_mask(x,y,z) == cc_id) {
                        if (y > cc_y_max) cc_y_max = y;
                    }

                    if (input_mask(x,y,z) == 10) {
                        if (y > bs_y_max) bs_y_max = y;
                    }


                }
            }

            ave_x = round(ave_x/ave_n);
            all_ave_x.push_back(ave_x);



        }


        int sh_x = 3;

        


        for (int y=0; y<output_mask.GetY(); y++) {

            ave_x = all_ave_x[y];

            for (int z=0; z<output_mask.GetZ(); z++) {
                for (int x=0; x<output_mask.GetX(); x++) {
    
                    if (input_mask(x,y,z) == cc_id || input_mask(x,y,z) == internal_id || input_mask(x,y,z) == remove_id) {
                        if (x < ave_x - sh_x) output_mask(x,y,z) = org_mask(x,y,z);
                        if (x > ave_x + sh_x) output_mask(x,y,z) = org_mask(x,y,z); 

                        if (y > y_max) output_mask(x,y,z) = org_mask(x,y,z);
                        if (y < y_min) output_mask(x,y,z) = org_mask(x,y,z);

                    }

                    if (input_mask(x,y,z) == third_roi) {
                        if ( (x > ave_x - sh_x - 1) && (x < ave_x + sh_x + 1) ) output_mask(x,y,z) = internal_id;
                    }


                    if (input_mask(x,y,z) == cavum_roi) {
                        if ( (x > ave_x - sh_x - 1) && (x < ave_x + sh_x + 1) ) output_mask(x,y,z) = internal_id;
                    }

                    if (input_mask(x,y,z) == 16) {
                        if ( (x > ave_x - sh_x - 1) && (x < ave_x + sh_x + 1) ) output_mask(x,y,z) = internal_id;
                    }

                    if (input_mask(x,y,z) == 17) {
                        if ( (x > ave_x - sh_x - 1) && (x < ave_x + sh_x + 1) ) output_mask(x,y,z) = internal_id;
                    }

                    // if (input_mask(x,y,z) == 1) {
                    //     if ( (x > ave_x - sh_x - 1) && (x < ave_x + sh_x + 1) ) output_mask(x,y,z) = internal_id;
                    // }

                    // if (input_mask(x,y,z) == 2) {
                    //     if ( (x > ave_x - sh_x - 1) && (x < ave_x + sh_x + 1) ) output_mask(x,y,z) = internal_id;
                    // }



                }
            }
        }


    for (int y=0; y<output_mask.GetY(); y++) {
        for (int x=0; x<output_mask.GetX(); x++) {

            int max_cc = -1000;
            for (int z=0; z<output_mask.GetZ(); z++) {

                if (output_mask(x,y,z) == cc_id) {
                    if (z > max_cc) max_cc = z;
                }

            }

            for (int z=0; z<output_mask.GetZ(); z++) {

                if (output_mask(x,y,z) == internal_id) {
                    if (z > max_cc-1) output_mask(x,y,z) = org_mask(x,y,z);
                }

            }


        }
    }


        double diff_cc_bs = cc_y_max - bs_y_max;

        z_max = -1000;
        z_min = 1000;

        double cc_z_min = 1000;


        for (int y=0; y<output_mask.GetY(); y++) { 
            
            
            for (int z=0; z<output_mask.GetZ(); z++) {
                for (int x=0; x<output_mask.GetX(); x++) {
    
                    if (output_mask(x,y,z) == internal_id) {
                        if (z > z_max) z_max = z;
                        if (z < z_min) z_min = z;

                    }

                    if (output_mask(x,y,z) == cc_id && (y > (y_max - ((y_max - y_min)/3)))) {
                        if (z < cc_z_min) cc_z_min = z;

                    }

                }
            }
        }


        cout << cc_z_min << " " << z_min << endl;

        for (int y=0; y<output_mask.GetY(); y++) {
        for (int x=0; x<output_mask.GetX(); x++) {
 


            // for (int z=0; z<output_mask.GetZ(); z++) {
            for (int z=cc_z_min; z>(z_min+(cc_z_min-z_min)*0.0-1); z=z-1) {

                if (output_mask(x,y,z) == internal_id) {


                    double dz = 0.7*(cc_z_min - z);

                    if (y > (cc_y_max - dz)) output_mask(x,y,z) = remove_id;

                    // if (z > (max_cc -1) ) output_mask(x,y,z) = org_mask(x,y,z);

                }

            }

        }
    }


    for (int y=0; y<output_mask.GetY(); y++) { 
            for (int z=0; z<output_mask.GetZ(); z++) {
                for (int x=0; x<output_mask.GetX(); x++) {
    
                    if (output_mask(x,y,z) == 66) {

                        output_mask(x,y,z) = org_mask(x,y,z);

                    }

                }
            }
        }


    // }
                                     
    output_mask.Write(output_name);
    
    
    // cout << "---------------------------------------------------------------------" << endl;
    
    
    
    return 0;
}
