

#ifndef DTX_DEC_H
#define DTX_DEC_H
#define dtx_dec_h "$Id $"

#include "typedef.h"
#include "d_plsf.h"
#include "gc_pred.h"
#include "c_g_aver.h"
#include "frame.h"
#include "dtx_common_def.h"
/*--------------------------------------------------------------------------*/
#ifdef __cplusplus
extern "C"
{
#endif

    /*----------------------------------------------------------------------------
    ; MACROS
    ; Define module specific macros here
    ----------------------------------------------------------------------------*/

    /*----------------------------------------------------------------------------
    ; DEFINES
    ; Include all pre-processor statements here.
    ----------------------------------------------------------------------------*/

    /*----------------------------------------------------------------------------
    ; EXTERNAL VARIABLES REFERENCES
    ; Declare variables used in this module but defined elsewhere
    ----------------------------------------------------------------------------*/

    /*----------------------------------------------------------------------------
    ; SIMPLE TYPEDEF'S
    ----------------------------------------------------------------------------*/


    /*----------------------------------------------------------------------------
    ; ENUMERATED TYPEDEF'S
    ----------------------------------------------------------------------------*/
    enum DTXStateType {SPEECH = 0, DTX, DTX_MUTE};

    /*----------------------------------------------------------------------------
    ; STRUCTURES TYPEDEF'S
    ----------------------------------------------------------------------------*/
    typedef struct
    {
        Word16 since_last_sid;
        Word16 true_sid_period_inv;
        Word16 log_en;
        Word16 old_log_en;
        Word32 L_pn_seed_rx;
        Word16 lsp[M];
        Word16 lsp_old[M];

        Word16 lsf_hist[M*DTX_HIST_SIZE];
        Word16 lsf_hist_ptr;
        Word16 lsf_hist_mean[M*DTX_HIST_SIZE];
        Word16 log_pg_mean;
        Word16 log_en_hist[DTX_HIST_SIZE];
        Word16 log_en_hist_ptr;

        Word16 log_en_adjust;

        Word16 dtxHangoverCount;
        Word16 decAnaElapsedCount;

        Word16 sid_frame;
        Word16 valid_data;
        Word16 dtxHangoverAdded;

        enum DTXStateType dtxGlobalState;     /* contains previous state */
        /* updated in main decoder */

        Word16 data_updated;      /* marker to know if CNI data is ever renewed */

    } dtx_decState;

    /*----------------------------------------------------------------------------
    ; GLOBAL FUNCTION DEFINITIONS
    ; Function Prototype declaration
    ----------------------------------------------------------------------------*/

    /*
     *  Function    : dtx_dec_reset
     *  Purpose     : Resets state memory
     *  Returns     : 0 on success
     */
    Word16 dtx_dec_reset(dtx_decState *st);

    /*
     *  Function    : dtx_dec
     *  Purpose     :
     *  Description :
     */
    void dtx_dec(
        dtx_decState *st,                /* i/o : State struct                    */
        Word16 mem_syn[],                /* i/o : AMR decoder state               */
        D_plsfState* lsfState,           /* i/o : decoder lsf states              */
        gc_predState* predState,         /* i/o : prediction states               */
        Cb_gain_averageState* averState, /* i/o : CB gain average states          */
        enum DTXStateType new_state,     /* i   : new DTX state                   */
        enum Mode mode,                  /* i   : AMR mode                        */
        Word16 parm[],                   /* i   : Vector of synthesis parameters  */
        Word16 synth[],                  /* o   : synthesised speech              */
        Word16 A_t[],                    /* o   : decoded LP filter in 4 subframes*/
        Flag   *pOverflow
    );

    void dtx_dec_activity_update(dtx_decState *st,
                                 Word16 lsf[],
                                 Word16 frame[],
                                 Flag   *pOverflow);

    /*
     *  Function    : rx_dtx_handler
     *  Purpose     : reads the frame type and checks history
     *  Description : to decide what kind of DTX/CNI action to perform
     */
    enum DTXStateType rx_dtx_handler(dtx_decState *st,           /* i/o : State struct */
                                     enum RXFrameType frame_type,/* i   : Frame type   */
                                     Flag *pOverflow);

    /*----------------------------------------------------------------------------
    ; END
    ----------------------------------------------------------------------------*/
#ifdef __cplusplus
}
#endif

#endif /* DEC_AMR_H_ */