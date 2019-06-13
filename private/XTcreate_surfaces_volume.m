%  create a surface object in Imaris with a threshold based on Otsu's method
%
%
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory.
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%        <Item name="create a surface object automatically" icon="Matlab" tooltip="create a surface object automatically">
%          <Command>MatlabXT::XTcreate_surfaces_volume(%i)</Command>
%        </Item>
%      </Menu>
%    </CustomTools>
%  
%
%  Description:
%   
%   create a surface object in Imaris with a threshold based on Otsu's method
%   multiple thresholds are computed and the one producing a surface closest to the expected volume is used
%
%   Arguments:
%   XTcreate_surfaces_volume(ImarisApplicationID,channel,smoothing,background_subtraction,
%                            largest_sphere,number_thresholds,expected_volume_min,expected_volume_max,
%                            channel_filter,intensity_filter,surface_name,time_min,time_max)
%     channel 
%     smoothing [um]
%     background_subtraction [bool]
%     largest_sphere [um]
%     number_thresholds 
%     expected_volume_min [um3] 
%     expected_volume_max [um3]
%     channel_filter ; channel used for filtering surfaces, surfaces with average intensity in the channel given below the threshold is removed
%     intensity_filter ; intensity used for filtering surfaces, surfaces with average intensity in the channel given below the threshold is removed
%     surface_name
%     time_min [frame]; starts at 1
%     time_max [frame]
%
%       Created by Eike Urs M?nnich (eike-urs.moennich@mpibpc.mpg.de)

function [surface,thresh_best] = XTcreate_surfaces_volume(aImarisApplicationID,varargin)

    if isempty(cell2mat(strfind(javaclasspath('-all'), 'ImarisLib.jar')))
          mlock
          javaaddpath ImarisLib.jar
          munlock
    end

    % connect to Imaris interface
    if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
      vImarisLib = ImarisLib;
      if ischar(aImarisApplicationID)
        aImarisApplicationID = round(str2double(aImarisApplicationID));
      end
      vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
    else
      vImarisApplication = aImarisApplicationID;
    end

imaris_version_date = get_imaris_version(vImarisApplication);

[options,dataset_info,dataset] = check_inputs(vImarisApplication);
    

ImageProcessing = vImarisApplication.GetImageProcessing;
scene = vImarisApplication.GetSurpassScene;
if isempty(scene)
    errordlg('Error: Could not get Imaris Scene object')
end
factory = vImarisApplication.GetFactory;


if(options.background_subtraction==0)
   options.largest_sphere =0; 
end

surface = factory.CreateSurfaces;

%create surfaces per frame in case of bleaching
for time = options.time_min:options.time_max

    disp(['processing time: ', num2str(time)])
    
    data_volume = get_current_data(dataset,options.channel,options,time,dataset_info);

    volume_finite = sum(isfinite(data_volume(:)))* dataset_info.pixelsize_x * dataset_info.pixelsize_y * dataset_info.pixelsize_z;
    if(volume_finite <options.expected_volume_min)
        warning('Not enough signal available to meet minimum desired surface volume')
        surface_current = [];
        thresh_best = -1;
        return
    end
    
    %determine ROI for surface detection
    profile_x = squeeze(any(any(isfinite(data_volume),3),2));
    profile_y = squeeze(any(any(isfinite(data_volume),3),1));
    profile_z = squeeze(any(any(isfinite(data_volume),2),1));
    ROI_x_start = find(profile_x,1,'first');
    ROI_x_end   = find(profile_x,1,'last');
    ROI_y_start = find(profile_y,1,'first');
    ROI_y_end   = find(profile_y,1,'last');
    ROI_z_start = find(profile_z,1,'first');
    ROI_z_end   = find(profile_z,1,'last');
    ROI = [ROI_x_start ROI_y_start ROI_z_start time-1 ROI_x_end ROI_y_end ROI_z_end time-1];
    average_expected_volume = (options.expected_volume_max + options.expected_volume_min )/2;

    %try to use as few thresholds as possible by starting to use just 1 and scaling up
    thresh_vol_closest_index = -1;
    for number_thresholds = 1:options.number_thresholds

        thresholds = multithresh(data_volume,number_thresholds);

        size_all_surfaces = zeros(number_thresholds,1);
        for i=1:number_thresholds
            size_all_surfaces(i) = sum(data_volume(:)>thresholds(i)) * dataset_info.pixelsize_x * dataset_info.pixelsize_y * dataset_info.pixelsize_z;
        end

        within_boundaries = size_all_surfaces <= options.expected_volume_max &  size_all_surfaces >= options.expected_volume_min;
        if(any(within_boundaries) )
            if(sum(within_boundaries)>1)

                [~,thresh_vol_closest_index] = min(abs(average_expected_volume-size_all_surfaces));
            else
                thresh_vol_closest_index = find(within_boundaries);
            end
            break;
        end


    end

    if(thresh_vol_closest_index < 0)
        warning('Could not find any threshold creating a surface of appropriate size')
        surface_current = [];
        thresh_best = -1;
        continue
    end
    thresh_best = thresholds(thresh_vol_closest_index);

    if(length(varargin)~=8)
        if(options.channel_filter >0)
            filter_string = ['"Intensity Mean Ch=' num2str(options.channel_filter) '" above ' num2str(options.intensity_filter)];
        else
            filter_string = [];
        end
    else
        filter_string = [];
    end

    surface_current = ImageProcessing.DetectSurfaces (dataset,ROI, options.channel-1 , options.smoothing, options.largest_sphere, false, thresh_best, filter_string);
    
    %combine surfaces from all frames into a single object
    if(thresh_best>-1)
        surface_ids_all = int32(surface_current.GetIds);
        number_of_surfaces = numel(surface_current.GetIds);
        if(~isempty(surface_ids_all))
%             if(imaris_year >2017)
            if(imaris_version_date > datetime(2017,7,15))
                surface_current.CopySurfacesToSurfaces(0:(number_of_surfaces-1), surface);
            else
%                 XTCopySurfacesToSurfaces(surface_current,surface,surface_ids_all);
                XTCopySurfacesToSurfaces(surface_current,surface,0:(number_of_surfaces-1));
            end
        else
            warning('Could not create any surface')
        end
    end
end

surface.SetName(options.surface_name);
scene.AddChild(surface,-1);



function options= prompt_for_options(dataset_info)
    %prompt for parameters of image data
    prompt = {'Enter channel number(starts at 1):',...
              'Enter smoothing size(um):',...
              'Perform Background Subtraction? (0/1):',...
              'Size of largest sphere fitting into object(um):',...
              'number of thresholds to be computed (use as few as possible):',...
              'minimum of expected total volume of surface object(um3):',...
              'maximum of expected total volume of surface object(um3):',...
              'Enter channel for filtering surfaces by mean intensity(0 for no filtering):',...
              'Enter intensity for filtering surfaces by channel:',...
              'Enter name for the surface object:',...
              'Enter first frame to use:',...
              'Enter last frame to use:',...
              };
    dlg_title = 'Input';
    num_lines = 1;
    defaultans = {'3',num2str(dataset_info.pixelsize_x*2),'1',num2str(dataset_info.pixelsize_x*8),'5','200','1000','-1','10','surface automatic','1','1'};
    answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    if(isempty(answer))
        return;
    end
    options.channel = str2double(answer{1});
    options.smoothing =str2double(answer{2});
    options.background_subtraction =str2double(answer{3});
    options.largest_sphere =str2double(answer{4});
    options.number_thresholds =str2double(answer{5});
    options.expected_volume_min =str2double(answer{6});
    options.expected_volume_max =str2double(answer{7});
    options.channel_filter=str2double(answer{8});
    options.intensity_filter=str2double(answer{9});
    options.surface_name = answer{10};
    options.time_min = str2double(answer{11});
    options.time_max = str2double(answer{12});
    if(~all(isfinite(str2double(answer))))
        return;
    end
end



function dataset_out = get_current_data(dataset,channel,options,time,dataset_info)

    dataset_org = dataset.GetDataVolumeFloats(channel-1,time-1);
    sigma_smooth = options.smoothing ./ [dataset_info.pixelsize_x dataset_info.pixelsize_y dataset_info.pixelsize_z] * 2; %smoothing within each slice
    sigma_bckgr = options.largest_sphere ./ [dataset_info.pixelsize_x dataset_info.pixelsize_y dataset_info.pixelsize_z] *0.8; %smoothing within each slice
    
    if(~(all(sigma_bckgr>0)))
        options.background_subtraction = false;
    end
    
    %background subtraction    
    if(options.background_subtraction)
        dataset_bckgr  = zeros(size(dataset_org));
        for ii=1:size(dataset_org,3)
            dataset_bckgr (:,:,ii) = imgaussfilt(dataset_org(:,:,ii),sigma_bckgr(1:2));
        end
        
        dataset_filt = dataset_org-dataset_bckgr;
        dataset_filt(dataset_filt<0)=0;
    else
        dataset_filt = dataset_org;
    end
    
    %use median filter to remove single hot pixels
    dataset_out = zeros(size(dataset_org));
    if(all(sigma_smooth>0))
        for ii=1:size(dataset_filt,3)
%             dataset_filt (:,:,i) = imgaussfilt(dataset_org(:,:,i),sigma_smooth(1:2));
            dataset_out(:,:,ii) = medfilt2(dataset_filt(:,:,ii),round_odd(sigma_smooth(1:2)));
        end
    else
        dataset_out = dataset_filt;
    end
    
    
    if(options.channel_filter <= dataset_info.number_channels && options.channel_filter > 0 )
        dataset_filt_2 = dataset.GetDataVolumeFloats(options.channel_filter-1,time-1);
        if(all(sigma_smooth>0))
            for ii=1:size(dataset_filt_2,3)
    %             dataset_filt_2(:,:,i) = imgaussfilt(dataset_filt_2(:,:,i),sigma_smooth(1:2));
                dataset_filt_2(:,:,ii) = medfilt2(dataset_filt_2(:,:,ii),round_odd(sigma_smooth(1:2)));
            end
        end
        dataset_out(dataset_filt_2<options.intensity_filter) = nan;
    end

    
end

function S = round_odd(S)
    % round to nearest odd integer.
    idx = mod(S,2)<1;
    S = floor(S);
    S(idx) = S(idx)+1;
end

function [options,dataset_info,dataset] = check_inputs(imaris)
    dataset = imaris.GetDataSet;

    dataset_info.pixelsize_x = (dataset.GetExtendMaxX-dataset.GetExtendMinX)/dataset.GetSizeX;
    dataset_info.pixelsize_y = (dataset.GetExtendMaxY-dataset.GetExtendMinY)/dataset.GetSizeY;
    dataset_info.pixelsize_z = (dataset.GetExtendMaxZ-dataset.GetExtendMinZ)/dataset.GetSizeZ;

    dataset_info.extendminx = dataset.GetExtendMinX;
    dataset_info.extendminy = dataset.GetExtendMinY;
    dataset_info.extendminz = dataset.GetExtendMinZ;

    dataset_info.extendmaxx = dataset.GetExtendMaxX;
    dataset_info.extendmaxy = dataset.GetExtendMaxY;
    dataset_info.extendmaxz = dataset.GetExtendMaxZ;

    volume_total = abs(dataset_info.extendmaxx-dataset_info.extendminx) * abs(dataset_info.extendmaxy-dataset_info.extendminy) * abs(dataset_info.extendmaxz-dataset_info.extendminz);

    dataset_info.number_channels = dataset.GetSizeC;

    dataset_info.time_last = int32(dataset.GetSizeT);
    
    nargin_org = length(varargin);
    
    %set default values
    if  nargin_org == 0
        options = prompt_for_options(dataset_info);
    else
        options.channel =1;
        options.smoothing =0;
        options.background_subtraction =0;
        options.largest_sphere =0;
        options.number_thresholds =1;
        options.expected_volume_min =0;
        options.expected_volume_max =volume_total;
        options.channel_filter =-1;
        options.intensity_filter =-1;
        options.surface_name = 'automatic surface';
        options.time_min = 1;
        options.time_max = dataset_info.time_last;
    end

    %check if inputs are given and legal
    if nargin_org>=1
        if ~isempty(varargin{1})
            if floor(varargin{1})==varargin{1} % if integer valued
                options.channel =varargin{1};
            else
                warning('value for channel is not integer, using channel 1 instead')
            end
        end
    end

    if nargin_org>=2
        if ~isempty(varargin{2})
            if isnumeric(varargin{2}) 
                options.smoothing =varargin{2};
            else
                warning('value for smoothing is not numeric, using 0 instead')
            end
        end
    end

    if nargin_org>=3
        if ~isempty(varargin{3})
            if varargin{3}==0 || varargin{3}==1% if boolean valued
                options.background_subtraction =varargin{3};
            else
                warning('value for background_subtraction is not bool, not using background subtraction')
            end
        end
    end 
    
    if nargin_org>=4
        if ~isempty(varargin{4})
            if isnumeric(varargin{4}) 
                options.largest_sphere =varargin{4};
            else
                warning('value for largest_sphere is not numeric, not using any local contrast')
            end
        end
    end 
    
    if nargin_org>=5
        if ~isempty(varargin{5})
            if floor(varargin{5})==varargin{5} % if integer valued
                options.number_thresholds =varargin{5};
            else
                warning('value for number of thresholds is not integer, just 1 threshold instead')
            end
        end
    end 
    
    if nargin_org>=6
        if ~isempty(varargin{6})
            if isnumeric(varargin{6}) && varargin{6} >= 0
                options.expected_volume_min =varargin{6};
            else
                warning('value for expected_volume_min is not legal, using 0 instead')
            end
        end
    end 
    
    if nargin_org>=7
        if ~isempty(varargin{7})
            if isnumeric(varargin{7}) && varargin{7} > 0
                options.expected_volume_max =varargin{7};
            else
                warning('value for expected_volume_max is not legal, using full volume instead')
            end
        end
    end 
    
    if nargin_org>=8
        if ~isempty(varargin{8})
            if(ischar(varargin{8}))
                options.surface_name = varargin{8};
            else
                if floor(varargin{8})==varargin{8} % if integer valued
                    options.channel_filter =varargin{8};
                else
                    warning('value for channel_filter is not integer, not filtering by intensity')
                end
            end
        end
    end 
    
    if nargin_org>=9
        if ~isempty(varargin{9})
            if isnumeric(varargin{9}) 
                options.intensity_filter =varargin{9};
            else
                warning('value for intensity_filter is not numeric, not filtering by intensity')
            end
        end
    end 
    
    if nargin_org>=10
        if ~isempty(varargin{10})
            if ischar(varargin{10})
                options.surface_name =varargin{10};
            else
                warning('surface name is not legal is not char array, using default name instead')
            end
        end
    end 
    
    if nargin_org>=11
        if ~isempty(varargin{11})
            if floor(varargin{11})==varargin{11} &&  varargin{11}>=1% if integer valued
                if varargin{11} >= 0 %if valid
                    options.time_min =varargin{11};
                else
                    warning('value for time_min is not valid, starting at frame 1 instead')
                    options.time_min =1;
                end
            else
                warning('value for time_min is not integer, starting at frame 1 instead')
            end
        end
    end 
    
    if nargin_org>=12
        if ~isempty(varargin{12})
            if floor(varargin{12})==varargin{12} &&  varargin{12}>=1% if integer valued
                if varargin{12} >= options.time_min %if valid
                    options.time_max =varargin{12};
                else
                    warning('value for time_max is not valid, ending at last frame instead')
                    options.time_max = dataset_info.time_last;
                end
            else
                warning('value for time_max is not integer, ending at last frame instead')
            end
        end
    end 
end
end