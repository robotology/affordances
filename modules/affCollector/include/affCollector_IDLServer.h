// This is an automatically-generated file.
// It could get re-generated if the ALLOW_IDL_GENERATION flag is on.

#ifndef YARP_THRIFT_GENERATOR_affCollector_IDLServer
#define YARP_THRIFT_GENERATOR_affCollector_IDLServer

#include <yarp/os/Wire.h>
#include <yarp/os/idl/WireTypes.h>

class affCollector_IDLServer;


/**
 * affCollector_IDLServer
 * Interface.
 */
class affCollector_IDLServer : public yarp::os::Wire {
public:
  affCollector_IDLServer();
  /**
   * Start the module
   * @return true/false on success/failure
   */
  virtual bool start();
  /**
   * Quit the module
   * @return true/false on success/failure
   */
  virtual bool quit();
  /**
   * Activates a category (or creates if note previously exisiting), for which affordance data (action success rate) can be updated.
   * @return the index of the active (new or not) label
   */
  virtual int32_t setlabel(const std::string& label);
  /**
   * Returns the active label (object/tool/cateagory/etc, user defined).
   */
  virtual std::string getlabel();
  /**
   * For the active label, update its affordance success rate for a given action, based on its effect.
   * @returns the updated success rate for that action and label
   */
  virtual double updateAff(const int32_t act, const double eff, const int32_t labI = -1);
  /**
   * Returns the success rate for all actions in the repertoire for a given known label (the active one by default).
   * if label == 'all', returns a concatenated vector with all konwn affordances.
   */
  virtual std::vector<double>  getAffs(const std::string& label = "active");
  /**
   * Returns the history of effects for a given action and known label (the active one by default).
   */
  virtual std::vector<double>  getAffHist(const int32_t act, const std::string& label = "active");
  /**
   *  Based on the previously learnt affordances, returns the best label for a given action/task.
   * @return true/false on success/failure
   */
  virtual std::string selectTool(const int32_t action);
  /**
   * Clears all the learnt affordances of the active label, and sets it to unknown.
   * @return true/false on success/failure
   */
  virtual bool clear();
  /**
   * Clears all the learnt affordances all labels, and sets them to unknown.
   * @return true/false on success/failure
   */
  virtual bool clearAll();
  /**
   * Activates/Deactivates more verbose execution of the module.
   * @return true/false on success/failure
   */
  virtual bool verbose(const bool verb);
  virtual bool read(yarp::os::ConnectionReader& connection);
  virtual std::vector<std::string> help(const std::string& functionName="--all");
};

#endif