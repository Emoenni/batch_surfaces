%   Batch process multiple datasets, create a surface object for each automatically by Otsu's method
%   the thresholds are determined per frame
%     
%     Copyright (C) 2019  Eike Urs M?nnich
% 
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
%
%
%   Creates an excel file containing some statistics:
%
%   Sum of all surfaces total and mean intensity of
%   each channel 
%   Total volume and area of the surfaces 
%   Report number of pixels with value at or above given threshold (saturated)
%
%   These statistics are determined irrespective of time, therefore their
%   value is limited for timeseries
%
%   Optionally, an imaris object may be given as argument in order to not
%   have to select ImarisLib.jar manually
%
%       Created by Eike Urs M?nnich (eike-urs.moennich@mpibpc.mpg.de)

function batch_surfaces(varargin)

    %connect to Imaris
    imaris = get_imaris(varargin);

    options = prompt_for_options();
    
    file_ending = '_with_surfaces_MTs'; %this will be appended to the filenames to create new *.ims files containing the new surfaces
    
    path_images = [uigetdir('','Select the folder which contains the image files') '\'];
    
    filename_list = get_filename_list(path_images,file_ending);

    time = 0; %timeseries are currently not supported, keep this at 0
    data =[];
    
    %loop through all image files
    for i=1:numel(filename_list)
        if(~isempty(filename_list{i} ))
            
            %try to load image, continue with the next file if it is not possible
            [filename_list,status] = load_image(imaris,path_images,filename_list,i);
            if(status == 1)
                continue
            end

            dataset = imaris.GetDataSet;
            dataset_info = get_dataset_info(dataset);
            
            %get threshold and create surface in imaris
%             if(options.channel_filter > 0 && options.channel_filter<= dataset_info.number_channels)
                [surface,thresh] = XTcreate_surfaces_volume(imaris,options.channel,options.smoothing,options.background_subtraction,options.largest_sphere,options.number_thresholds,options.expected_volume_min,options.expected_volume_max,options.channel_filter,options.intensity_filter,options.surface_name,options.time_min,options.time_max);
%             else
%                 [surface,thresh] = XTcreate_surfaces_volume(imaris,options.channel,options.smoothing,options.background_subtraction,options.largest_sphere,options.number_thresholds,options.expected_volume_min,options.expected_volume_max,options.surface_name);
%             end
            
            %check for success
            if(isempty(surface))
                data(i,:) = [zeros(1,dataset_info.number_channels)  zeros(1,dataset_info.number_channels)  zeros(1,dataset_info.number_channels)   0 0];
                continue;
            end
            
            %filter surfaces by distance from common CoM
            surface_filtered = apply_filter(surface,options);


            %gather statistics
            data = get_data(surface_filtered,dataset_info,options,dataset,data,i,time);

            imaris.FileSave([path_images filename_list{i} file_ending '.ims'],[]);

            remove_scene_objects(imaris); % object not removed from the scene will remain in the next scene after loading a new file
        end


    end

    %combine statistics and used settings in table for export into excel
    %sheet
    
    additional_information = {['channel: ' num2str(options.channel )] ['smoothing: ' num2str(options.smoothing )] ['background_subtraction: ' num2str(options.background_subtraction )] ['largest_sphere: ' num2str(options.largest_sphere )] ['number_thresholds: ' num2str(options.number_thresholds )] ['expected_volume_min: ' num2str(options.expected_volume_min )] ['expected_volume_max: ' num2str(options.expected_volume_max )] ['saturation_int: ' num2str(options.saturation_int )] ['max_distance: ' num2str(options.max_distance )] ['channel_filter:' num2str(options.channel_filter)] ['intensity_filter:' num2str(options.intensity_filter)] ['time_min:' num2str(options.time_min)] ['time_max:' num2str(options.time_max)]}';

    %create names for data for all channels
    names_int_mean = cell(0,0);
    names_int_total = cell(0,0);
    names_int_saturated = cell(0,0);
    for i=1:dataset_info.number_channels
        names_int_mean = horzcat(names_int_mean,{['intensity_mean_channel_' num2str(i)]});
        names_int_total = horzcat(names_int_total,{['intensity_total_channel_' num2str(i)]});
        names_int_saturated = horzcat(names_int_saturated,{['number_voxel_saturated_' num2str(i)]});
    end
    names = horzcat(names_int_mean,names_int_total,names_int_saturated,{'volume'},{ 'area'});

    %filling column of table with empty strings
    number_elements_missing = numel(filename_list) - 13;
    if(number_elements_missing >= 0)
        additional_information = vertcat(additional_information, cell(number_elements_missing,1) );
    else
        filename_list = vertcat(filename_list, cell(abs(number_elements_missing),1));
        data = [data; nan(abs(number_elements_missing),size(data,2))];
    end

    table_data = array2table(data,'VariableNames',names);
    table_out = [cell2table(filename_list) table_data cell2table(additional_information)];
    
    %export data
    write_to_exc_file(table_out,path_images)

end

function options= prompt_for_options()
    %prompt for parameters of image data
    prompt = {'Enter channel number(starts at 1):',...
              'Enter smoothing size(?m):',...
              'Perform Background Subtraction? (0/1):',...
              'Size of largest sphere fitting into object(?m):',...
              'number of thresholds to be computed (use as few as possible):',...
              'minimum of expected total volume of surface object(?m?):',...
              'maximum of expected total volume of surface object(?m?):',...
              'saturation intensity:',...
              'max distance of a surface from the spindle',...
              'Enter channel for filtering surfaces by mean intensity(0 for no filtering):',...
              'Enter intensity for filtering surfaces by channel:',...
              'Enter name for the surfaces object',...
              'Enter first frame to use:',...
              'Enter last frame to use[-1 for final frame]:',...
              };
    dlg_title = 'Input';
    num_lines = 1;
    defaultans = {'1','0.15','1','0.6','5','50','1000','255','-1','-1','10','surface automatic','1','-1'};
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
    options.saturation_int =str2double(answer{8});
    options.max_distance=str2double(answer{9});
    options.channel_filter=str2double(answer{10});
    options.intensity_filter=str2double(answer{11});
    options.surface_name=answer{12};
    options.time_min = str2double(answer{13});
    options.time_max = str2double(answer{14});


    if(~all(isfinite(str2double(answer))))
        return;
    end
end

function write_to_exc_file(data,path)
    disp('trying to write to file ')
    fileindex =1;
    FILENAME = 'surface data';
    FILE_ENDING = '.xls';
    try
        FILENAME_cur = FILENAME;
        while(exist([path FILENAME_cur FILE_ENDING]))
            %change filename until one is unused
            FILENAME_cur = [FILENAME '(' num2str(fileindex) ')'];
            fileindex = fileindex +1;
        end
        writetable(data,[path FILENAME_cur FILE_ENDING]);
    catch
        error('could not write to file')
    end
end

function remove_scene_objects(imaris)
    
    scene = imaris.GetSurpassScene;
    if(isempty(scene))
        return
    end
    factory = imaris.GetFactory;
    children_to_remove = cell(0,1);
    index =0;
    %gather all objects in Imaris scene
    for i=0:(scene.GetNumberOfChildren-1)
        current_child = scene.GetChild(i);
        if(~isempty(current_child))
            flag_keep = factory.IsDataSet(current_child) | factory.IsFrame(current_child) | factory.IsLightSource(current_child) | factory.IsSurpassCamera(current_child) | factory.IsVolume(current_child);
            if(~flag_keep)
                index = index+1;
                children_to_remove{index,1} = current_child;
            end
        end
    end
    %remove all objects
    for i=1:index
        scene.RemoveChild(children_to_remove{i});
    end
end

function imaris = get_imaris(varargin)
    imaris =[];
    if(~isempty(varargin))
        if(isa(varargin{1},'Imaris.IApplicationPrxHelper'))
            imaris = varargin{1};
        end
    end
    if(isempty(imaris))
%         imaris = GetImaris_pathed('C:\Program Files\Bitplane\Imaris x64 9.2.1\XT\rtmatlab');
        imaris = GetImaris_pathed('');
    end
end

function filename_list = get_filename_list(path,file_ending)
    %list all imaris files to be analyzed
    filename_list = cell(2,1);

    content_dir = dir(path);

    % create filename list
    index =0;
    for i=3:size(content_dir,1) % first two entries are just a spot and two spots
        [~,name,ext] = fileparts(content_dir(i).name) ;
        if(~isequal(content_dir(i).name , '.') && ~isequal(content_dir(i).name ,'..') && isequal(ext,'.ims') && ~isequal(name((end-numel(file_ending)+1):end),file_ending))
            index = index+1;
            filename_list{index,1} = content_dir(i).name;
        end
    end
end

function [filename_list,status] = load_image(imaris,path_images,filename_list,i)

    %remove '.ims' if its still in the filename
    if(strcmp(filename_list{i}(end-3:end) ,'.ims'))
        filename_list{i} = filename_list{i}(1:end-4);
    end
    
    status = 0;
    filename_full = [path_images filename_list{i} '.ims'];

    if(exist(filename_full, 'file') == 0)
        warning([filename_full ' not found, continuing with next']);
        status = 1;
        return
    end

    %load file into Imaris
    try
        imaris.FileOpen(filename_full,[]);
    catch
        warndlg(['Could not open ' filename_full ' ,skipping'])
        filename_list{i} = [];
        status = 1;
        return
    end 
end

function dataset_info = get_dataset_info(dataset)

    dataset_info.number_channels = dataset.GetSizeC; 
    dataset_info.pixelsize_x = (dataset.GetExtendMaxX-dataset.GetExtendMinX)/dataset.GetSizeX;
    dataset_info.pixelsize_y = (dataset.GetExtendMaxY-dataset.GetExtendMinY)/dataset.GetSizeY;
    dataset_info.pixelsize_z = (dataset.GetExtendMaxZ-dataset.GetExtendMinZ)/dataset.GetSizeZ;

    dataset_info.extendminx = dataset.GetExtendMinX;
    dataset_info.extendminy = dataset.GetExtendMinY;
    dataset_info.extendminz = dataset.GetExtendMinZ;

    dataset_info.extendmaxx = dataset.GetExtendMaxX;
    dataset_info.extendmaxy = dataset.GetExtendMaxY;
    dataset_info.extendmaxz = dataset.GetExtendMaxZ;

    dataset_info.sizex = dataset.GetSizeX;
    dataset_info.sizey = dataset.GetSizeY;
    dataset_info.sizez = dataset.GetSizeZ;
end

function surface_filtered = apply_filter(surface,options)
    surface.SetName('surface automatic')

    volumes = get_statistic(surface,'Volume');

    Position_X = get_statistic(surface,'Position X');
    Position_Y = get_statistic(surface,'Position Y');
    Position_Z = get_statistic(surface,'Position Z');

    CoM_X = sum(Position_X .* volumes) / sum(volumes);
    CoM_Y = sum(Position_Y .* volumes) / sum(volumes);
    CoM_Z = sum(Position_Z .* volumes) / sum(volumes);
    distances_from_CoM = sqrt((Position_X - CoM_X).^2 + (Position_Y - CoM_Y).^2 + (Position_Z - CoM_Z).^2 );

    if(options.max_distance>0)
        ids_too_far = distances_from_CoM > options.max_distance;
    else
        ids_too_far = false(size(distances_from_CoM));
    end

    ids = double(surface.GetIds);

    ids_remove = find(ids_too_far);

    surface_filtered = surface;

    surface_filtered.SetName(options.surface_name)
    for j=numel(ids_remove):-1:1
        surface_filtered.RemoveSurface(ids(ids_remove(j)))
    end 
end

function data = get_data(surface_filtered,dataset_info,options,dataset,data,i,time)
    volume = sum(get_statistic(surface_filtered,'Volume'));
    area = sum(get_statistic(surface_filtered,'Area'));

    Mask_dataset = surface_filtered.GetMask(dataset_info.extendminx,dataset_info.extendminy,dataset_info.extendminz,dataset_info.extendmaxx,dataset_info.extendmaxy,dataset_info.extendmaxz,dataset_info.sizex,dataset_info.sizey,dataset_info.sizez,time);
    Mask_array = logical(Mask_dataset.GetDataVolumeShorts(0,time));

    for j=1:dataset_info.number_channels
        data_array = dataset.GetDataVolumeShorts(j-1,time);
        number_voxel_saturated(j) = sum(data_array(Mask_array) >= options.saturation_int);
        intensity_total_channel(j) = sum(get_statistic(surface_filtered,'Intensity Sum',j));
        intensity_mean_channel(j) = intensity_total_channel(j) /volume;
    end

    data(i,:) = [intensity_mean_channel  intensity_total_channel  number_voxel_saturated   volume area];
end