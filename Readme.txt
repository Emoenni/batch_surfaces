		Batch Surfaces

--------------------------------------------------------------------------------------------------------------------------------------

Overview:

Creates surface objects in Imaris automatically based on the multileveled Otsu's method. Determines as many thresholds as necessary to 
produce a surface within given volume restrictions. 
The thresholds are determined per frame, not globally
All *.ims files within a chosen folder will be processed. The surfaces are saved automatically in new *.ims files.

--------------------------------------------------------------------------------------------------------------------------------------

Requirements:

'Matlab' (2018b is tested and works)
'Matlab Image Processing Toolbox'
'Matlab Statistics and Machine Learning Toolbox'
'Imaris' 
'Imaris XTensions module'

--------------------------------------------------------------------------------------------------------------------------------------

Notes: 

Imaris needs to be already running

run "batch_surfaces()" in Matlab to start

only works for reading *.ims files, use "export" (ctrl+E) in Imaris or the dedicated program "ImarisFileConverter" to create these

XTcreate_surfaces_volume.m can be used as an XTension inside Imaris to create surfaces on a single scene with timeseries

detects whether Imaris version is 9 or older and adapts

can use an Imaris object as argument create this by using 'getimaris_pathed.m' and select the ImarisLib.jar file which should be located in: 'C:\Program Files\Bitplane\Imaris x64 9.1.2\XT\matlab' or similar
if started without an argument, an interface is going to ask you to locate ImarisLib.jar manually

only tested on windows 10

You may change the path to ImarisLib.jar in line 207 of batch_surfaces.m to avoid dialogue at each call by creating the imaris object automatically

volumes of surfaces may be outside of the specified constraints due to the usage of a median filter in the script, 
the inbuilt imaris functions to create the final surface object behave slightly differently
this matters only in extreme cases
--------------------------------------------------------------------------------------------------------------------------------------

Troubleshooting:

After automatic creation direct loading of the files may not show the surface objects. In this case you may have to restart Imaris.
The number of channels must be constant for all files.

if "out of memory" error appears. Try to increase "Java Heap Memory" in Matlab Preferences under "General"

if Imaris cannot be found, restart Imaris and Matlab
