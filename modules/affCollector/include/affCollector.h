/*
 * AFFORDANCE COLLECTOR MODULE
 * Copyright (C) 2016 iCub Facility - Istituto Italiano di Tecnologia
 * Author: Tanis Mar
 * email: tanis.mar@iit.it
 * Permission is granted to copy, distribute, and/or modify this program
 * under the terms of the GNU General Public License, version 2 or any
 * later version published by the Free Software Foundation.
 *
 * A copy of the license can be found at
 * http://www.robotcub.org/icub/license/gpl.txt
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details
*/

#ifndef __AFFCOLLECTOR_H__
#define __AFFCOLLECTOR_H__

// Includes
#include <iostream>
#include <algorithm>
#include <math.h>
#include <vector>
#include <ctime>
#include <map>

// YARP - iCub libs
#include <yarp/os/all.h>
#include <yarp/sig/all.h>
#include <yarp/math/Rand.h>
#include <yarp/math/Math.h>


#include <affCollector_IDLServer.h>

/**********************************************************
    PUBLIC METHODS
/**********************************************************/

/**********************************************************/
class AffCollector : public yarp::os::RFModule, public affCollector_IDLServer
{
protected:
    /* module parameters */
    yarp::os::RpcServer rpcInPort;                                  // port to handle incoming commands
    yarp::os::BufferedPort<yarp::os::Bottle> affInPort;             // Receives pairs of action-effect information to update affordance information
    yarp::os::BufferedPort<yarp::os::Bottle> labelsInPort;          // Receives labels for affordances
    yarp::os::BufferedPort<yarp::os::Bottle> affOutPort;            // Streams the success rate (affordances) of the active label

    /* class variables */

    bool verb;
    bool closing;
    bool binAff;

    int activeLabel;        // Indicates index of the active label
    int numAct;             // Number of actions in teh ation repertoire

    std::vector < std::string>  knownLabels;                        // maps string labels to index in affordance matrix
    std::vector < std::vector < std::vector <double> > > affHist;   // Keeps track of all effects, for all acts and all labels: affHist[labI][act].push_back(eff)
    std::vector < std::vector < double> > knownAffs;                // Saves learned success rates: knownAffs[labI][act] = mean(affHist[labI][act] (along recorded effects))

    /* functions*/    

    // bool                        updateAffordance(const int labI,const int act,const double eff);
    // double                      getAffordance(const int labI,const int act);                  // returns success rate of action act on/with entity I.



public:
    
    // RPC Accesible methods
    int                         setlabel(const std::string& label = "tool");
    std::string                 getlabel();

    double                      updateAff(const int act,const double eff, const int labI = -1);
    std::vector<double>         getAffs(const std::string& label = "active");
    std::vector<double>         getAffHist(const int act, const std::string& label = "active");

    std::string                 selectTool(const int act);

    bool                        clear();
    bool                        clearAll();

    // Helper functions
    double                      vecAvg(const std::vector<double>& vec);
    
    // module control //
    bool						attach(yarp::os::RpcServer &source);
    //bool						verbose(const bool verb);
    bool						quit();

    // RF modules overrides
    bool						configure(yarp::os::ResourceFinder &rf);
    bool						interruptModule();
    bool						close();
    bool						updateModule();
    double						getPeriod();
};

#endif
//empty line to make gcc happy