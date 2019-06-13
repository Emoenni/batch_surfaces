%connect to imaris via a given path

function [aImarisApplication, vImarisLib , vObjectId] = GetImaris_pathed(folder)

librarypath = [folder, '\ImarisLib.jar'];
if(isempty(dir(librarypath)))
    warning('cannot find interface library ''ImarisLib.jar'' please select the matlab folder inside the installation folder of Imaris');
    [FileName,PathName] = uigetfile('*.jar','Select the ImarisLib file in /XT/matlab/ in the Imaris installation folder');
    librarypath = [PathName ,FileName];
end

javaaddpath(librarypath);

vImarisLib = ImarisLib;
vServer = vImarisLib.GetServer;
if(isempty(vServer))
    errordlg('Could not locate Imaris, Imaris needs to be running!')
    error('Could not locate Imaris, Imaris needs to be running!')
end
vNumberOfObjects = vServer.GetNumberOfObjects;
vNumberOfObjects = int16(vNumberOfObjects);
for vIndex = 0:vNumberOfObjects-1
  vObjectId = vServer.GetObjectID(vIndex);
  break % work with the ID, return first one (replace this line by "disp(aObjectId)" to display all the object ids registered)
end

aImarisApplication = vImarisLib.GetApplication(vObjectId);