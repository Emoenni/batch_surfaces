%   extract statistic from Imaris specified by the statistics name and
%   optionally a channel
%
%
%
%       Created by Eike Urs M?nnich (eike-urs.moennich@mpibpc.mpg.de)
%


function [output,ids_sorted] = get_statistic(object,statistic_name,varargin)
   
   if(~isempty(varargin))
       if(isnumeric(varargin{1}))
            channel = varargin{1};
       else
            channel =[];
            warndlg('channel must be numeric')
       end
   else
       channel =[];
   end
    %gather all necessary data from Imaris
   flag_start_found = false;
   statistics = object.GetStatistics;
   stat_area_start = -1;
   stat_area_end = -1;
   
   factors = statistics.mFactors;
   factor_names = strtrim(string(char(statistics.mFactorNames)));
   id_factor_channel = factor_names == 'Channel';
   channels_all = str2double(string(char(factors(id_factor_channel,:))));
   %find entries in the whole statistics data corresponding to the desired statistic
   if(isempty(channel))
       for i=1:length(statistics.mIds)
           if(flag_start_found == false && statistics.mNames(i) == java.lang.String(statistic_name) )
               stat_area_start = i;
               flag_start_found = true;
           end
           if(flag_start_found == true  && statistics.mNames(i) ~= java.lang.String(statistic_name) )
               stat_area_end = i-1;
               break;
           end
       end
   else
       for i=1:length(statistics.mIds)
           if(flag_start_found == false && statistics.mNames(i) == java.lang.String(statistic_name) && channels_all(i) == channel)
               stat_area_start = i;
               flag_start_found = true;
           end
           if(flag_start_found == true  && (statistics.mNames(i) ~= java.lang.String(statistic_name) || channels_all(i) ~= channel))
               stat_area_end = i-1;
               break;
           end
       end
   end
   if(stat_area_start == -1 )
       disp([statistic_name , ' not found'])
       output = 0;
       ids =0;
       ids_sorted =0;
       return
   end
   %extract data from the whole statistics data
   if(stat_area_end == -1 )
       output = statistics.mValues(stat_area_start:end);
       ids = statistics.mIds(stat_area_start:end);
       [ids_sorted,sorting_ids] = sort(ids);
       output = output(sorting_ids);
   else
       output = statistics.mValues(stat_area_start:stat_area_end);
       ids = statistics.mIds(stat_area_start:stat_area_end);
       [ids_sorted,sorting_ids] = sort(ids);
       output = output(sorting_ids);
   end
end
