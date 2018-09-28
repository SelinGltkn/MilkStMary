# Function Get_data returns a xray.DataSet of reqested station data/metadata
def get_mesowest_data(token,sta_list,var_list,date_start,date_end):
    # INPUT
    # m MESOWEST token variable
    # sta_list list of station ids requested
    # var_list list of variables requested
    # StateDate start of data
    # date_end end of data

    #### Function for combining xray data variables into a single array with new labeled dimension
    # Creator Karl Lapo
    def combinevars(ds_in,dat_vars,new_dim_name='new_dim',combinevarname='new_var'):
        ds_out = xray.Dataset()
        ds_out = xray.concat([ds_in[dv] for dv in dat_vars],dim='new_dim')
        ds_out = ds_out.rename({'new_dim': new_dim_name})
        ds_out.coords[new_dim_name] = dat_vars
        ds_out.name = combinevarname

        return ds_out

    # Grab all time series data from all stations for a given date range
    print 'Grabbed all station data'
    data_json = token.timeseries(stid=sta_list, start=date_start, end=date_end)

    # Get Station Info
    N_sta = data_json['SUMMARY']['NUMBER_OF_OBJECTS']
    print 'Found ',N_sta,' Stations'
    Elev  = [ast.literal_eval(json.dumps(data_json['STATION'][cs]['ELEVATION'])) for cs in range(0,N_sta)]
    Lat   = [ast.literal_eval(json.dumps(data_json['STATION'][cs]['LATITUDE'])) for cs in range(0,N_sta)]
    Lon   = [ast.literal_eval(json.dumps(data_json['STATION'][cs]['LONGITUDE'])) for cs in range(0,N_sta)]
    NAME  = [ast.literal_eval(json.dumps(data_json['STATION'][cs]['NAME'])) for cs in range(0,N_sta)]
    ID    = [ast.literal_eval(json.dumps(data_json['STATION'][cs]['STID'])) for cs in range(0,N_sta)]
    print 'Got all station info'

    if N_sta == 0: # No stations were found for this period
        return None

    # Get timestamp timeseries for all stations (may be different lengths and different time steps)
    timestamp = []
    [timestamp.append(ob['OBSERVATIONS']['date_time']) for ob in data_json['STATION']]
    print 'Got timestamps for each station'

    # Loop through each variable to extract
    print 'Looping through each station to extract data'
    DS_list = [] # Empty list of each dataset containing one variable
    for Vn,cVar in enumerate(var_list):
        print 'Current variable is ',cVar
        # Get timeseries of data for all stations
        temp_list = []
        for Sn,ob in enumerate(data_json['STATION']):
            #print ob['NAME']
            # Not all stations have all variables, which will throw an error
            # If station has this Variable
            try:
                temp_list.append(ob['OBSERVATIONS'][cVar])
            # Else add missing values as padding (so xray can handle it)
            except:
                # Create empty array of -9999
                temp_vals = np.empty(np.size(timestamp[Sn]))
                temp_vals[:] = np.NAN
                temp_list.append(temp_vals)
                print 'Station ',ob['NAME'],' is missing ',[cVar],'Padding with -9999s'

        print 'Got ',cVar,'data from',len(temp_list),'stations'

        # Make dictionary of site and xray data array
        # Warning, must cast returned types to float64
        print '.....Converting to a dictionary list of xray.DataArrays'
        dict1 = {}
        for csta in range(0,len(temp_list)):
            c_t = [datetime.strptime(ast.literal_eval(json.dumps(timestamp[csta][cd])), '%Y-%m-%dT%H:%M:%SZ') for cd in range(len(timestamp[csta]))]
            dict1[ID[csta]] = xray.DataArray(np.array(temp_list[csta],dtype='float64'), coords=[c_t], dims=['time'], name=ID[csta])
        #print dict1

        # Make it a dataset
        print '.....Converting to a xray.Dataset'
        ds_temp_Var = xray.Dataset(dict1)
        #print ds_temp_Var

        # Resample to common time step as Data contains mix of 15, 10, and 5 min data
        # For some variables we want to sample
        if cVar=='wind_direction_set_1':
            print '.....Resampling to 1 hour time step. Using Median!!!! Timestamp out is END of period!!!!'
            ds_temp_Var_1hr = ds_temp_Var.resample(freq='H',dim='time',how='median',label='right')
            #print ds_temp_Var_1hr
        else:
            print '.....Resampling to 1 hour time step. Using mean!!!! Timestamp out is END of period!!!!'
            ds_temp_Var_1hr = ds_temp_Var.resample(freq='H',dim='time',how='mean',label='right')
            #print ds_temp_Var_1hr

        # Combine stations
        print '.....Combining stations'
        DS_list.append(combinevars(ds_temp_Var_1hr,ds_temp_Var_1hr.data_vars,new_dim_name='site',combinevarname=cVar))

    # Make dictionary list
    DIC1 = dict(zip([cv.name for cv in DS_list],DS_list))

    # Combine all Datasets
    print 'Combine all datasets (if multple varibles requested)'
    ds_ALL = xray.Dataset(DIC1)
    #print ds_ALL

    print 'Update coords'
    # Fill in descriptive variables
    ds_ALL.coords['lat'] = ('site',[float(x) for x in Lat])
    ds_ALL.coords['lon'] = ('site',[float(x) for x in Lon])
    ds_ALL.coords['elev'] = ('site',[float(x) for x in Elev])
    ds_ALL.coords['sta_name'] = ('site',NAME)

    return ds_ALL
