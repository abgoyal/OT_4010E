

#ifndef RTSP_PAR_COM_TUNABLE_H_
#define RTSP_PAR_COM_TUNABLE_H_


// this is a tunable area for ParCom; Player and Server might require
// different parameters; set them here
//

// player RTSP ParCom tuning
//changed from 1000 to 4000 because ASF TCP streaming.
#define RTSP_MAX_FULL_REQUEST_SIZE 4000
#define RTSP_PARSER_BUFFER_SIZE 4000
#define RTSP_MAX_NUMBER_OF_FIELDS 20
#define RTSP_HUGE_NUMBER_OF_FIELDS_IN_PARSER 60
#define RTSP_MAX_NUMBER_OF_RTP_INFO_ENTRIES 10
#define RTSP_MAX_NUMBER_OF_TRANSPORT_ENTRIES 5
#define RTSP_RESYNC_PRESERVE_SIZE 20

//#ifdef RTSP_PLAYLIST_SUPPORT
#define RTSP_MAX_NUMBER_OF_PLAYLIST_ERROR_ENTRIES 10
#define RTSP_MAX_NUMBER_OF_SUPPORTED_ENTRIES 32
//#endif

#endif // RTSP_PAR_COM_TUNABLE_H_
