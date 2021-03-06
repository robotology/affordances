#!/usr/bin/lua 

-- Copyright: (C) 2016 iCub Facility - Istituto Italiano di Tecnologia (IIT)
-- Authors: Tanis Mar <tanis.mar@iit.it>
-- Copy Policy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

-- Description: 
-- Manager module (pseudo state machine), to control the flow of tool use demo (aka Xperience).


-- XXX All these consts could be set by ini file
-- -- -- DEclare consts.
OBJECT_MEMORY   = 0.5       -- seconds   
SENSITIVITY     = 0.8       -- 80 percent
XOFFSET         = 0.0       -- m
YOFFSET         = -0.03     -- m
ZOFFSET         = 0.0       -- m

--                  -0.3                   0.05                     0.4    
--                 _________________________|_________________________ -> Y
--            -0.6 |                      | |                        |
--                 |                        |                        |
--                 |         UPLEFT         |        UPRIGHT         |
--                 |                        |                        |
--           -0.41 |______________________|_|________________________|  (orig -0.38)
--                 |                      | |                        |
--                 |                        |                        |
--                 |       BOTTOMLEFT       |      BOTTOMRIGHT       |
--                 |                        |                        |
--            -0.1 |______________________|_|________________________|
--              X  V                      |    
--                                       0.0            -- area is dsipalced to right to help tool actions

-- LIMIT LINES
MIN_X = -0.6        -- meter
MAX_X = -0.1
MIN_Y = -0.3
MAX_Y = 0.4
CENTER_X = -0.4
CENTER_Y = 0.05

-- ZONES
-- UPRIGHT
UPRIGHT_ZONE_X = {min=MIN_X, max=CENTER_X}
UPRIGHT_ZONE_Y = {min=CENTER_Y, max=MAX_Y}

-- UPLEFT
UPLEFT_ZONE_X = {min=MIN_X, max=CENTER_X}
UPLEFT_ZONE_Y = {min=MIN_Y, max=CENTER_Y}

--BOTTOMRIGHT
BOTTOMRIGHT_ZONE_X = {min=CENTER_X, max=MAX_X}
BOTTOMRIGHT_ZONE_Y = {min=CENTER_Y, max=MAX_Y}

--BOTTOMLEFT
REACHABLE_ZONE_X  = {min=CENTER_X, max=MAX_X}    
REACHABLE_ZONE_Y  = {min=MIN_Y, max=CENTER_Y}      

-- ACTION LIST
ACTION_LIST = {["no_act"] = -1, ["drag_right"] = 0, ["drag_down_right"] = 1, ["drag_left"] = 2, ["drag_down"] = 3 , ["drag_up"] = 4 , ["drag_up_left"] = 5}

-- TOOL LIST
--TOOL_LIST = {"RAK1", "RAK2", "HOE1", "HOE2", "SHO1","SHO2", "HOK1","HOK2","STI1","STI2"}
TOOL_LIST = {"RAK2"}
-- TOOL_LIST_SIM = {"rak1", "rak2", "rak3", "hoe1", "hoe2","hoe3","hoe1","hoe2","hoe3","sti1","sti2","sti3","sho1","sho2","sho3"}
--TOOL_LIST = {"RAK2"}
--rakeBlue = RAK2
--rakeGreen = RAK3 
--shovelGreen = SHO1
--shovelOrange = SHO2
--shovelYellow = SHO3

-- -- -- -- -- -- -- -- Begin module -- -- -- -- -- -- -- -- -- -- -- 
local signal = require("posix.signal")
require("yarp")

rf = yarp.ResourceFinder()
rf:setVerbose(false)
rf:configure(arg)
rf:setDefaultContext("AffordancesProject")

--robot = rf:check("robot",Value("icub")).asString()

explore_helper_file = rf:findFile("aff-explorer_helper.lua")
if explore_helper_file == "" then
    print("Cannot find aff-explorer_helper.lua")
    return false 
end
dofile(explore_helper_file)

yarp_helper_file = rf:findFile("yarp_helper.lua")
if yarp_helper_file == "" then
    print("Cannot find yarp_helper.lua")
    return false 
end
dofile(yarp_helper_file)

signal.signal(signal.SIGINT, function(signum)
  state = "exit";
end)

yarp.Network()

-- Declare ports
port_blobs = yarp.BufferedPortBottle()
port_acteff = yarp.Port()

--rpc
ar_rpc_io = yarp.RpcClient()
o3de_rpc = yarp.RpcClient()
tmanager_rpc = yarp.RpcClient()
ispeak_rpc = yarp.RpcClient()
affcollect_rpc = yarp.RpcClient()

-- Open ports
port_blobs:open("/affExplorer/blobs:i")
port_acteff:open("/affExplorer/act_eff:o")

-- rpc
ar_rpc_io:open("/affExplorer/are:rpc")
o3de_rpc:open("/affExplorer/o3de:rpc")
tmanager_rpc:open("/affExplorer/t3dm:rpc")
ispeak_rpc:open("/affExplorer/ispeak:rpc")
affcollect_rpc:open("/affExplorer/affcol:rpc")

-- XXX this should be deleted when module works (connectiosn should go through yarpmanager):
if robot == "icub" then
    ret = yarp.NetworkBase_connect("/lbpExtract/blobs:o",port_blobs:getName())
    if ret == false then print("cannot connect  from /lbpExtract/blobs:o") end
else
    ret = yarp.NetworkBase_connect("/lbpExtract/blobs:o",port_blobs:getName())
    if ret == false then print("cannot connect  from /lbpExtract/blobs:o") end
end

ret = yarp.NetworkBase_connect(port_acteff:getName(), "/affCollector/aff:i")
if ret == false then print("cannot connect to /affCollector/aff:i") end

ret = yarp.NetworkBase_connect(o3de_rpc:getName(), "/objects3DExplorer/rpc:i")
if ret == false then print("cannot connect to /objects3DExplorer/rpc:i") end

ret = yarp.NetworkBase_connect(affcollect_rpc:getName(), "/affCollector/rpc:i")
if ret == false then print("cannot connect to /affCollector/rpc:i") end

ret = yarp.NetworkBase_connect(tmanager_rpc:getName(), "/tool3DManager/rpc:i")
if ret == false then print("cannot connect to /tool3DManager/rpc:i") end

ret = yarp.NetworkBase_connect(ar_rpc_io:getName(), "/actionsRenderingEngine/cmd:io")
if ret == false then print("cannot connect to /actionsRenderingEngine/cmd:io") end

-- XXX till here

-- Before exploring, check if it has a tool (received by rpc as label) 
-- If it doesnt, 
    --> ask for tool from list (so it can load the model)
    --> do alignment and get pose
    --> tell affCollector to setlabel  of tool-pose
-- When it has it:
    -- >xx find objects at blobs
    --> xx decide action (random based on zone)
    --> xx perform action
    --> observe effect (success/fail) -> update affCollector (action , effect)
    --> Do around 60 times, until each action is done about 10 times (more or less)
    --> Ask to change tool(-pose) and repeat


---------------- Modifiable variables for module flow:: 

bin_aff = false
trials_x_tp = 5
SIM = false


--for key,value in pairs(ACTION_LIST) do print(key,value) end

 ------------------------------ Initialization -----------------------------
print("Module running ... ")
t0 = yarp.Time_now()
math.randomseed( os.time() )
state = "no_tool"
--state = "do_action"
object_list = {}                        -- for keeping the memory of objects
object = {}
tp_trial_count = 0
go_home()

-- -- -- -- -- -- -- -- -- -- -- updateModule -- -- -- -- -- -- -- -- -- -- -- 
while state ~= "exit" do

    print("")
    -- Get a tool
    if state == "no_tool" then
        print("State = ",state)
        if SIM then
            tool_name = select_tool(TOOL_LIST_SIM, 0)     -- SIM
        else
            tool_name = select_tool(TOOL_LIST, 0)         -- REAL
        end
        print("Tool Selected:", tool_name)

        if tool_name  ~= " " then 
            if SIM then
                tool_pose = load_tool(tool_name)          -- SIM
            else
                tool_pose = ask_for_tool(tool_name)       -- REAL        
            end
            if tool_pose ~= "invalid" then
                set_tool_label(tool_pose)         
                print("Tool-Pose:",tool_pose)
                state = "do_action"
                go_home()
            end
       end
    end
    -- Find object, perform action      
    if state ==  "do_action" then
        print("State = ",state)

        if SIM then                                     -- SIM
            --        act_i = aff_generator(0)           -- data generator for TEST
            object = localize_object()            
            act_i = explore(object)                      -- find the location of the object and select action
            action = find_key(ACTION_LIST, act_i )
            if act_i >= 0 then 
                print("Performing action ", action)
                local actOK = perform_action(action, object)           -- Perform selected action
                if actOK then
                    print("Action Performed: ", action)
                    state = "comp_effect"       
                else
                    print("Action ", action, "could not be executed" )             
                end
            end
            go_home()

        else                                            -- REAL

            local blobs = port_blobs:read(false)
            if blobs ~= nil and blobs:size() >= 0 then    
                if update_objects(blobs) == true then           -- updates the global variable objects (objects in memory)
                    object = object_list[1]               -- for exploring we assume there is only one object on the table
                    act_i = explore(object)                     -- find the location of the object and select action
                    action = find_key(ACTION_LIST, act_i)
                    if act_i >= 0 then 
                        print("Performing action ", action)
                        local actOK = perform_action(action, object)
                        if actOK then
                            print("Action Performed: ", action)
                            state = "comp_effect"       
                        else
                            print("Action ", action, "could not be executed" )             
                        end           -- Perform selected action
                    end
                    --go_home()
                end
            end 
        end       
    end

    --  Observe and save effect  
    if state == "comp_effect" then
        print("")
        print("State = ",state)
        
        if SIM then
            print("Computing effect for trial: ", tp_trial_count)
            --local eff = aff_generator(1) -- generate act_i
            local object_prev = object                          -- saves previous object coordinates
            object = localize_object()
            local eff = comp_effect(object, object_prev, false)
            print("Effect Computed: ", eff)
            save_effect(act_i, eff)
            if tp_trial_count >= trials_x_tp then        -- after a number of trial with tool-pose, change tool
                state = "no_tool"                
                tp_trial_count = 0
                print("Performed enough actions for tool-pose: ", tool_pose)
                save_affordances()
            else
                state = "do_action"                                    
                tp_trial_count = tp_trial_count + 1                                   
            end


        else                        -- REAL
            local blobs = port_blobs:read(false);
            if blobs ~= nil and blobs:size() >= 0 then    
                local object_prev = object                          -- saves previous object coordinates
                if update_objects(blobs) == true then           -- updates the global variable objects (objects in memory)
                    object = object_list[1]
                    local eff = comp_effect(object, object_prev, bin_aff)
                    print("Effect Computed: ", eff)
                    save_effect(act_i, eff)                    
                    if tp_trial_count  >=  trials_x_tp then        -- after a number of trial with tool-pose, change tool
                        state = "no_tool"                
                        tp_trial_count = 0
                        save_affordances()
                    else
                        state = "do_action"
                        tp_trial_count = tp_trial_count + 1                                   
                    end
                end
            end
        end
    end  

    yarp.Time_delay(0.2) -- acts as getPeriod()
end
   
-- close ports
port_blobs:close()
port_acteff:close()

-- close rpcs
ar_rpc_io:close()
o3de_rpc:close()
tmanager_rpc:close()
ispeak_rpc:close()
affcollect_rpc:close()

-- close YARP connection
yarp.Network_fini()
