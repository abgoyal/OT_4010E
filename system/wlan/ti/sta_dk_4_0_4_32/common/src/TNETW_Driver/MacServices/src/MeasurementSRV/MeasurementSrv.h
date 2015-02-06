/** \file MeasurementSrv.h
 *  \brief This file include private definitions for the Measurement SRV module.
 *  \author Ronen Kalish
 *  \date 08-November-2005
 */
 /****************************************************************************
**+-----------------------------------------------------------------------+**
**|                                                                       |**
**| Copyright(c) 1998 - 2008 Texas Instruments. All rights reserved.      |**
**| All rights reserved.                                                  |**
**|                                                                       |**
**| Redistribution and use in source and binary forms, with or without    |**
**| modification, are permitted provided that the following conditions    |**
**| are met:                                                              |**
**|                                                                       |**
**|  * Redistributions of source code must retain the above copyright     |**
**|    notice, this list of conditions and the following disclaimer.      |**
**|  * Redistributions in binary form must reproduce the above copyright  |**
**|    notice, this list of conditions and the following disclaimer in    |**
**|    the documentation and/or other materials provided with the         |**
**|    distribution.                                                      |**
**|  * Neither the name Texas Instruments nor the names of its            |**
**|    contributors may be used to endorse or promote products derived    |**
**|    from this software without specific prior written permission.      |**
**|                                                                       |**
**| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS   |**
**| "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT     |**
**| LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR |**
**| A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT  |**
**| OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, |**
**| SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT      |**
**| LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, |**
**| DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY |**
**| THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT   |**
**| (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE |**
**| OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  |**
**|                                                                       |**
**+-----------------------------------------------------------------------+**
****************************************************************************/

#ifndef __MEASUREMENT_SRV_H__
#define __MEASUREMENT_SRV_H__

#include "osTIType.h"
#include "commonTypes.h"
#include "measurementTypes.h"
#include "MacServices_api.h"
#include "fsm.h"
#include "whalCtrl_api.h"
#include "MeasurementSrvSM.h"

/*
 ***********************************************************************
 *	Constant definitions.
 ***********************************************************************
 */
/* Time in milliseconds to receive a command complete for measure start / stop from the FW */
#define MSR_FW_GUARD_TIME   100 
#define DEF_SAMPLE_INTERVAL             (100)   /* expressed in microsec */
#define NOISE_HISTOGRAM_THRESHOLD           100
/* Get param callback flags  */
#define MSR_SRV_WAITING_CHANNEL_LOAD_RESULTS        0x01 /* channel load results are still pending */
#define MSR_SRV_WAITING_NOISE_HIST_RESULTS          0x02 /* noise histogram results are still pending */

/*
 ***********************************************************************
 *	Enums.
 ***********************************************************************
 */


/*
 ***********************************************************************
 *	Typedefs.
 ***********************************************************************
 */

/*
 ***********************************************************************
 *	Structure definitions.
 ***********************************************************************
 */

/** \struct measurementSRV_t
 * \brief This structure contains the measurement SRV object data
 */
typedef struct
{
   	mediumOccupancy_t			mediumOccupancyResults; /**< channel load results buffer */
    noiseHistogramResults_t     noiseHistogramResults;  /**< noise histogram results buffer */

	/* module handles */
    TI_HANDLE           hOS;                            /**< OS object handle */
	TI_HANDLE           hReport;                        /**< report object handle */
	TI_HANDLE           hPowerSaveSRV;                  /**< power save SRV object handle */
	TI_HANDLE           hHalCtrl;                       /**< HAL ctrl object handle */
    /* CB functions and objects */                                                        
    measurement_srvCompleteCB_t measurmentCompleteCBFunc;
                                                        /**< 
                                                         * upper layer (measurement manager) measurement complete 
                                                         * callback function
                                                         */
	TI_HANDLE           measurementCompleteCBObj;       /**< 
                                                         * upper layer (measurement manager) measurement complete
                                                         * callback object
                                                         */
	
	CmdResponseCB_t		commandResponseCBFunc;		    /**<
													 	 * upper layer command response CB, used for both start
                                                         * and stop. Passed down to the HAL and called when 
                                                         * the measurement command has been received by the FW
														 */
	TI_HANDLE			commandResponseCBObj;   	    /**<
														 * object parameter passed to the commandResposeFunc by 
                                                         * the HAL when it is called 
														 */

	failureEventCB_t		failureEventFunc;	/**<
											* upper layer Failure Event CB.
											* called when the scan command has been Timer Expiry
											*/
	TI_HANDLE			failureEventObj;		/**<
											* object parameter passed to the failureEventFunc
											* when it is called 
											*/
    /* Timers */
    TI_HANDLE           hRequestTimer[ MAX_NUM_OF_MSR_TYPES_IN_PARALLEL ];
                                                        /**< Timers for different measurement types */
    BOOLEAN             bRequestTimerRunning[ MAX_NUM_OF_MSR_TYPES_IN_PARALLEL ];
                                                        /**< Indicates whether each request timer is running */
    TI_HANDLE           hStartStopTimer;                /**< Timer for start / stop commands guard */
    BOOLEAN             bStartStopTimerRunning;         /**< 
                                                         * Indicates whether the start / stop command guard
                                                         * timer is running
                                                         */
    /* Misc stuff */
    BOOLEAN             bInRequest;                     /**<
                                                         * Indicates whether the SM is run within
                                                         * the measurement request context (if so, to avoid
                                                         * re-entrance, the complete function shouldn't
                                                         * be called on failure, but rather an invalid
                                                         * status should be returned)
                                                         */
    TI_STATUS           returnStatus;                   /**< 
                                                         * Holds the return code to the upper layer
                                                         * Used to save errors during SM operation.
                                                         */
    BOOL                bSendNullDataWhenExitPs;        /**< whether to send NULL data frame when exiting
                                                         * driver mode
                                                         */
    /* state machine */
    fsm_stateMachine_t*     SM;                         /**< 
                                                         * state machines for different
                                                         * scan types
                                                         */
    measurements_SRVSMStates_e 	SMState;                /**< state machine current states */
    /* measurement request */
    measurement_request_t   msrRequest;                 /**< measurement request parameters */
	measurement_reply_t		msrReply;					/**< measurement reply values */
	UINT32					requestRecptionTimeStampMs;	/**< The time in which the request was received. */
	UINT32					timeToRequestExpiryMs;		/**<
														 * The duration (in ms) from request receiption
														 * until it should actually start. Request is
														 * discarded if a longer period is required
														 */
	UINT8					pendingParamCBs;			/**<
														 * a bitmap indicating which get_param CBs are
														 * currently pending (noise histogram and/or
														 * channel load).
														 */
} measurementSRV_t;

/*
 ***********************************************************************
 *	External data definitions.
 ***********************************************************************
 */

/*
 ***********************************************************************
 *	External functions definitions
 ***********************************************************************
 */

/**
 * \author Ronen Kalish\n
 * \date 08-November-2005\n
 * \brief Creates the measurement SRV object
 *
 * Function Scope \e Public.\n
 * \param hOS - handle to the OS object.\n
 * \return a handle to the measurement SRV object, NULL if an error occurred.\n
 */
TI_HANDLE MacServices_measurementSRV_create( TI_HANDLE hOS );

/**
 * \author Ronen Kalish\n
 * \date 08-November-2005\n
 * \brief Initializes the measurement SRV object
 *
 * Function Scope \e Public.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \param hReport - handle to the report object.\n
 * \param hHALCtrl - handle to the HAL CTRL object.\n
 * \param hPowerSaveSRV - handle to the power save SRV object.\n
 */
void MacServices_measurementSRV_init( TI_HANDLE hMeasurementSRV, TI_HANDLE hReport, TI_HANDLE hHALCtrl,
                                      TI_HANDLE hPowerSaveSRV );

/**
 * \author Ronen Kalish\n
 * \date 08-November-2005\n
 * \brief Destroys the measurement SRV object
 *
 * Function Scope \e Public.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 */
void MacServices_measurementSRV_destroy( TI_HANDLE hMeasurementSRV );

/** 
 * \author Ronen Kalish\n
 * \date 13-November-2005\n
 * \brief Checks whether a beacon measurement is part of current measurement request
 *
 * Function Scope \e Private.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \return TRUE if a beacon measurement is part of current request, FALSE otherwise.\n
 */
BOOLEAN measurementSRVIsBeaconMeasureIncluded( TI_HANDLE hMeasurementSRV );

/** 
 * \author Ronen Kalish\n
 * \date 15-November-2005\n
 * \brief Finds the index for the measurement request with the shortest period 
 * (the one that has now completed).\n
 *
 * Function Scope \e Private.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \return index of the measurement request with the shortest duration.\n
 */
int measurementSRVFindMinDuration( TI_HANDLE hMeasurementSRV );

/** 
 * \author Ronen Kalish\n
 * \date 15-November-2005\n
 * \brief Handles an AP discovery timer expiry, by setting necessary values in the
 * reply struct.\n
 *
 * Function Scope \e Private.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \param requestIndex - index of the beacon request in the request structure.\n
 */
void measurementSRVHandleBeaconMsrComplete( TI_HANDLE hMeasurementSRV, int requestIndex );

/** 
 * \author Ronen Kalish\n
 * \date 15-November-2005\n
 * \brief Handles a channel load timer expiry, by requesting channel load 
 * results from the FW.\n
 *
 * Function Scope \e Private.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \param requestIndex - index of the channel load request in the request structure.\n
 */
void measurementSRVHandleChannelLoadComplete( TI_HANDLE hMeasurementSRV, int requestIndex );

/** 
 * \author Ronen Kalish\n
 * \date 15-November-2005\n
 * \brief Handles a nois histogram timer expiry, by requesting noise histogram
 * reaults from the FW.\n
 *
 * Function Scope \e Private.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \param requestIndex - indexof the beacon request in the request structure.\n
 */
void measurementSRVHandleNoiseHistogramComplete( TI_HANDLE hMeasurementSRV, int requestIndex );

/** 
 * \author Ronen Kalish\n
 * \date 16-November-2005\n
 * \brief Checks whether all measuremtn types had completed and all param CBs had been called.\n
 *
 * Function Scope \e Public.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \param status - the get_param call status.\n
 * \param CB_buf - pointer to the results buffer (already on the measurement SRV object)
 */
BOOLEAN measurementSRVIsMeasurementComplete( TI_HANDLE hMeasurementSRV );

/** 
 * \author Ronen Kalish\n
 * \date 17-November-2005\n
 * \brief Finds a measure type index in the measure request array.\n
 *
 * Function Scope \e Public.\n
 * \param hMeasurementSRV - handle to the measurement SRV object.\n
 * \param type - the measure type to look for.\n
 * \return the type index, -1 if not found.\n
 */
int measurementSRVFindIndexByType( TI_HANDLE hMeasurementSRV, measurement_type_e type );

/****************************************************************************************
 *                        measurementSRVRegisterFailureEventCB													*
 ****************************************************************************************
DESCRIPTION: Registers a failure event callback for scan error notifications.
			    
				                                                                                                   
INPUT:     	- hMeasurementSRV	- handle to the Measurement SRV object.		
			- failureEventCB 		- the failure event callback function.\n
			- hFailureEventObj 	- handle to the object passed to the failure event callback function.

OUTPUT:	
RETURN:    void.
****************************************************************************************/
void measurementSRVRegisterFailureEventCB( TI_HANDLE hMeasurementSRV, 
                                     void * failureEventCB, TI_HANDLE hFailureEventObj );

void measurementSRV_restart( TI_HANDLE hMeasurementSRV);

#endif /* __MEASUREMENT_SRV_H__ */
