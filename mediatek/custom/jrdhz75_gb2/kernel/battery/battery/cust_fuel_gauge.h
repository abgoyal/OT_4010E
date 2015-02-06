#include <mach/mt6575_typedefs.h>

#define FGAUGE_VOLTAGE_FACTOR           2.44 // mV
#define FGAUGE_CURRENT_FACTOR           6.25 // uV/Rsns
#define FGAUGE_CURRENT_OFFSET_FACTOR    1.56 // uV/Rsns
#define FGAUGE_CAR_FACTOR               6.25 // uV/Rsns
#define FGAUGE_RSNS_FACTOR              0.02 // Ohm

//#define COMPASATE_OCV                   80 // mV for evb
#define COMPASATE_OCV                   40 // mV for phone

#define BATTERY_VOLTAGE_MINIMUM         3400
#define BATTERY_VOLTAGE_MAXIMUM         4200

//20120921 modify by sunjiaojiao start ( max battery capacity)
#define BATTERY_CAPACITY_MAXIMUM        1400//1135
//20120921 modify by sunjiaojiao end ( max battery capacity)

#define TEMPERATURE_T0                  110
#define TEMPERATURE_T1                  0
#define TEMPERATURE_T2                  25
#define TEMPERATURE_T3                  50
#define TEMPERATURE_T                   255 // This should be fixed, never change the value

//20120921 modify by sunjiaojiao start( battery capacity)
#define BATT_CAPACITY                  1400// 1135
//20120921 modify by sunjiaojiao end( battery capacity)

#define ENABLE_SW_COULOMB_COUNTER       0 // 1 is enable, 0 is disable
//#define ENABLE_SW_COULOMB_COUNTER       1 // 1 is enable, 0 is disable

//#define FG_CURRENT_OFFSET_DISCHARGING 	31
#define FG_CURRENT_OFFSET_DISCHARGING 	0

#define FG_RESISTANCE 	20

#define FG_METER_RESISTANCE 	0
//#define FG_METER_RESISTANCE 	540 // current meter

//#define MAX_BOOTING_TIME_FGCURRENT	5*6 // 5 seconds, 6 points = 1s
#define MAX_BOOTING_TIME_FGCURRENT	1*10 // 10s

#if defined(CONFIG_POWER_EXT)
//#define OCV_BOARD_COMPESATE	32 //mV 
#define OCV_BOARD_COMPESATE	72 //mV 
#define R_FG_BOARD_BASE		1000
#define R_FG_BOARD_SLOPE	1000 //slope
#else
//#define OCV_BOARD_COMPESATE	0 //mV 
//#define OCV_BOARD_COMPESATE	48 //mV 
//#define OCV_BOARD_COMPESATE	25 //mV 
#define OCV_BOARD_COMPESATE	0 //mV 
#define R_FG_BOARD_BASE		1000
#define R_FG_BOARD_SLOPE	1000 //slope
//#define R_FG_BOARD_SLOPE	1057 //slope
//#define R_FG_BOARD_SLOPE	1075 //slope
#endif

//20120921 modify by sunjiaojiao start(QMAX)	
#define Q_MAX_POS_50	1409//1135
#define Q_MAX_POS_25	1400//1135
#define Q_MAX_POS_0	1306//1062
#define Q_MAX_NEG_10	1244//971

#define Q_MAX_POS_50_H_CURRENT	1387//1119
#define Q_MAX_POS_25_H_CURRENT	1360//1119
#define Q_MAX_POS_0_H_CURRENT	1180//959
#define Q_MAX_NEG_10_H_CURRENT	641//817
//20120921 modify by sunjiaojiao end (QMAX)	

#define R_FG_VALUE 				20 // mOhm, base is 20
#define CURRENT_DETECT_R_FG	100  //10mA

#define OSR_SELECT_7			0

//20120921 modify by sunjiaojiao start(CAR_TUNE_VALUE)	
#define CAR_TUNE_VALUE			100//106 //1.06
//20120921 modify by sunjiaojiao end(CAR_TUNE_VALUE)	
/////////////////////////////////////////////////////////////////////
// <DOD, Battery_Voltage> Table
/////////////////////////////////////////////////////////////////////
typedef struct _BATTERY_PROFILE_STRUC
{
    kal_int32 percentage;
    kal_int32 voltage;
} BATTERY_PROFILE_STRUC, *BATTERY_PROFILE_STRUC_P;

typedef enum
{
    T1_0C,
    T2_25C,
    T3_50C
} PROFILE_TEMPERATURE;

// T0 -10C
BATTERY_PROFILE_STRUC battery_profile_t0[] =
{
	{0  , 4164},
	{2  , 4145},
	{4  , 4119},
	{5  , 4084},
	{7  , 4042},
	{9  , 4006},
	{11 , 3987},
	{12 , 3974},
	{14 , 3963},
	{16 , 3951},
	{18 , 3941},
	{19 , 3928},
	{21 , 3919},
	{23 , 3906},
	{25 , 3897},
	{26 , 3883},
	{28 , 3873},
	{30 , 3858},
	{32 , 3846},
	{33 , 3835},
	{35 , 3825},
	{37 , 3815},
	{39 , 3807},
	{40 , 3802},
	{42 , 3796},
	{44 , 3793},
	{46 , 3791},
	{47 , 3788},  
	{49 , 3788}, 
	{51 , 3786},
	{53 , 3786},
	{55 , 3784},  
	{56 , 3782},
	{58 , 3780},
	{60 , 3778},
	{62 , 3776},
	{63 , 3770},
	{65 , 3764},
	{67 , 3753},
	{69 , 3741},
	{70 , 3728},
	{72 , 3711},
	{74 , 3692},
	{76 , 3670},
	{77 , 3646},
	{79 , 3618},
	{81 , 3591},
	{82 , 3575},
	{83 , 3565},
	{83 , 3556},
	{84 , 3550},
	{84 , 3546},
	{84 , 3540},
	{85 , 3538},
	{85 , 3533},
	{85 , 3531},
	{85 , 3529},
	{85 , 3527},
	{85 , 3526},
	{85 , 3521},
	{100 , 3400}
};      
        
// T1 0C
BATTERY_PROFILE_STRUC battery_profile_t1[] =
{       
	{0  , 4164},
	{2  , 4120},
	{4  , 4088},
	{5  , 4065},
	{7  , 4041},
	{9  , 4019},
	{11 , 4003},
	{12 , 3988},
	{14 , 3977},
	{16 , 3965},
	{18 , 3955},
	{19 , 3944},
	{21 , 3933},
	{23 , 3921},
	{25 , 3911},
	{26 , 3901},
	{28 , 3890},
	{30 , 3880},
	{32 , 3868},
	{33 , 3856},
	{35 , 3843},
	{37 , 3832},
	{39 , 3822},
	{40 , 3812},
	{42 , 3805},
	{44 , 3798},
	{46 , 3793},
	{47 , 3791},  
	{49 , 3787}, 
	{51 , 3785},
	{53 , 3785},
	{55 , 3784},  
	{56 , 3783},
	{58 , 3783},
	{60 , 3782},
	{62 , 3780},
	{63 , 3779},
	{65 , 3778},
	{67 , 3775},
	{69 , 3770},
	{70 , 3764},
	{72 , 3756},
	{74 , 3742},
	{76 , 3727},
	{77 , 3709},
	{79 , 3685},
	{81 , 3656},
	{83 , 3627},
	{84 , 3600},
	{86 , 3578},
	{88 , 3558},
	{90 , 3536},
	{91 , 3491},
	{92 , 3453},
	{93 , 3435},
	{93 , 3423},
	{93 , 3415},
	{93 , 3410},
	{93 , 3407},
	{94 , 3403},
	{100 , 3400}
};      

// T2 25C
BATTERY_PROFILE_STRUC battery_profile_t2[] =
{
	{0   , 4177},
	{2   , 4150},
	{4   , 4129},
	{5   , 4110},
	{7   , 4092},
	{9   , 4075},
	{11  , 4060},
	{12  , 4042},
	{14  , 4023},
	{16  , 4009},
	{18  , 3995},
	{19  , 3983},
	{21  , 3970},
	{23  , 3958},
	{25  , 3946},
	{26  , 3935},
	{28  , 3923},
	{30  , 3913},
	{32  , 3903},
	{33  , 3892},
	{35  , 3885},
	{37  , 3874},
	{39  , 3865},
	{40  , 3857},
	{42  , 3846},
	{44  , 3833},
	{46  , 3820},
	{47  , 3809},  
	{49  , 3800}, 
	{51  , 3793},
	{53  , 3788},
	{55  , 3785},  
	{56  , 3781},
	{58  , 3779},
	{60  , 3778},
	{62  , 3777},
	{63  , 3775},
	{65  , 3774},
	{67  , 3773},
	{69  , 3771},
	{70  , 3770},
	{72  , 3768},
	{74  , 3763},
	{76  , 3758},
	{77  , 3751},
	{79  , 3740},
	{81  , 3731},
	{83  , 3719},
	{84  , 3704},
	{86  , 3683},
	{88  , 3657},
	{90  , 3626},
	{91  , 3598},
	{93  , 3577},
	{95  , 3559},
	{97  , 3536},
	{99  , 3480},
	{100 , 3389},
	{100 , 3389},
	{100 , 3389},
	{100 , 3389}      
};

// T3 50C
BATTERY_PROFILE_STRUC battery_profile_t3[] =
{
	{0   , 4177},
	{2   , 4150},
	{4   , 4129},
	{5   , 4110},
	{7   , 4092},
	{9   , 4075},
	{11  , 4060},
	{12  , 4042},
	{14  , 4023},
	{16  , 4009},
	{18  , 3995},
	{19  , 3983},
	{21  , 3970},
	{23  , 3958},
	{25  , 3946},
	{26  , 3935},
	{28  , 3923},
	{30  , 3913},
	{32  , 3903},
	{33  , 3892},
	{35  , 3885},
	{37  , 3874},
	{39  , 3865},
	{40  , 3857},
	{42  , 3846},
	{44  , 3833},
	{46  , 3820},
	{47  , 3809},  
	{49  , 3800}, 
	{51  , 3793},
	{53  , 3788},
	{55  , 3785},  
	{56  , 3781},
	{58  , 3779},
	{60  , 3778},
	{62  , 3777},
	{63  , 3775},
	{65  , 3774},
	{67  , 3773},
	{69  , 3771},
	{70  , 3770},
	{72  , 3768},
	{74  , 3763},
	{76  , 3758},
	{77  , 3751},
	{79  , 3740},
	{81  , 3731},
	{83  , 3719},
	{84  , 3704},
	{86  , 3683},
	{88  , 3657},
	{90  , 3626},
	{91  , 3598},
	{93  , 3577},
	{95  , 3559},
	{97  , 3536},
	{99  , 3480},
	{100 , 3389},
	{100 , 3389},
	{100 , 3389},
	{100 , 3389} 
};             

// battery profile for actual temperature. The size should be the same as T1, T2 and T3
BATTERY_PROFILE_STRUC battery_profile_temperature[] =
{
  {0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },  
	{0  , 0 }, 
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },  
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 }
};      

/////////////////////////////////////////////////////////////////////
// <Rbat, Battery_Voltage> Table
/////////////////////////////////////////////////////////////////////
typedef struct _R_PROFILE_STRUC
{
    kal_int32 resistance; // Ohm
    kal_int32 voltage;
} R_PROFILE_STRUC, *R_PROFILE_STRUC_P;

// T0 -10C
R_PROFILE_STRUC r_profile_t0[] =
{
	{360 , 4164},
	{360 , 4145},
	{370 , 4119},
	{383 , 4084},
	{425 , 4042},
	{523 , 4006},
	{553 , 3987},
	{570 , 3974},
	{585 , 3963},
	{593 , 3951},
	{600 , 3941},
	{605 , 3928},
	{615 , 3919},
	{618 , 3906},
	{618 , 3897},
	{618 , 3883},
	{620 , 3873},
	{608 , 3858},
	{603 , 3846},
	{603 , 3835},
	{600 , 3825},
	{598 , 3815},
	{605 , 3807},
	{605 , 3802},
	{610 , 3796},
	{615 , 3793},
	{625 , 3791},
	{633 , 3788},  
	{640 , 3788}, 
	{648 , 3786},
	{660 , 3786},
	{663 , 3784},  
	{670 , 3782},
	{675 , 3780},
	{688 , 3778},
	{700 , 3776},
	{700 , 3770},
	{713 , 3764},
	{715 , 3753},
	{730 , 3741},
	{753 , 3728},
	{780 , 3711},
	{800 , 3692},
	{833 , 3670},
	{868 , 3646},
	{903 , 3618},
	{958 , 3591},
	{938 , 3575},
	{918 , 3565},
	{893 , 3556},
	{875 , 3550},
	{868 , 3546},
	{855 , 3540},
	{848 , 3538},
	{840 , 3533},
	{830 , 3531},
	{830 , 3529},
	{818 , 3527},
	{818 , 3526},
	{810 , 3521},
	{803 , 3400}
};      

// T1 0C
R_PROFILE_STRUC r_profile_t1[] =
{
	{268 , 4164},
	{268 , 4120},
	{315 , 4088},
	{333 , 4065},
	{335 , 4041},
	{340 , 4019},
	{353 , 4003},
	{358 , 3988},
	{368 , 3977},
	{370 , 3965},
	{375 , 3955},
	{383 , 3944},
	{390 , 3933},
	{390 , 3921},
	{390 , 3911},
	{400 , 3901},
	{398 , 3890},
	{400 , 3880},
	{393 , 3868},
	{385 , 3856},
	{375 , 3843},
	{368 , 3832},
	{368 , 3822},
	{363 , 3812},
	{363 , 3805},
	{358 , 3798},
	{360 , 3793},
	{368 , 3791},  
	{368 , 3787}, 
	{368 , 3785},
	{378 , 3785},
	{383 , 3784},  
	{385 , 3783},
	{395 , 3783},
	{400 , 3782},
	{405 , 3780},
	{413 , 3779},
	{420 , 3778},
	{423 , 3775},
	{425 , 3770},
	{425 , 3764},
	{438 , 3756},
	{445 , 3742},
	{458 , 3727},
	{480 , 3709},
	{490 , 3685},
	{490 , 3656},
	{488 , 3627},
	{495 , 3600},
	{523 , 3578},
	{563 , 3558},
	{633 , 3536},
	{688 , 3491},
	{638 , 3453},
	{590 , 3435},
	{560 , 3423},
	{543 , 3415},
	{528 , 3410},
	{525 , 3407},
	{515 , 3403},
	{498 , 3400}
};      

// T2 25C
R_PROFILE_STRUC r_profile_t2[] =
{
	{150 , 4177},
	{150 , 4150},
	{155 , 4129},
	{158 , 4110},
	{160 , 4092},
	{155 , 4075},
	{160 , 4060},
	{160 , 4042},
	{155 , 4023},
	{163 , 4009},
	{165 , 3995},
	{163 , 3983},
	{160 , 3970},
	{165 , 3958},
	{170 , 3946},
	{170 , 3935},
	{173 , 3923},
	{183 , 3913},
	{180 , 3903},
	{185 , 3892},
	{195 , 3885},
	{193 , 3874},
	{195 , 3865},
	{198 , 3857},
	{193 , 3846},
	{178 , 3833},
	{165 , 3820},
	{153 , 3809},  
	{148 , 3800}, 
	{150 , 3793},
	{148 , 3788},
	{150 , 3785},  
	{150 , 3781},
	{148 , 3779},
	{153 , 3778},
	{153 , 3777},
	{155 , 3775},
	{160 , 3774},
	{163 , 3773},
	{165 , 3771},
	{163 , 3770},
	{168 , 3768},
	{165 , 3763},
	{168 , 3758},
	{163 , 3751},
	{163 , 3740},
	{165 , 3731},
	{178 , 3719},
	{185 , 3704},
	{188 , 3683},
	{185 , 3657},
	{180 , 3626},
	{173 , 3598},
	{178 , 3577},
	{188 , 3559},
	{198 , 3536},
	{188 , 3480},
	{203 , 3389},
	{203 , 3389},
	{203 , 3389},
	{203 , 3389}      
};

// T3 50C
R_PROFILE_STRUC r_profile_t3[] =
{
	{150 , 4177},
	{150 , 4150},
	{155 , 4129},
	{158 , 4110},
	{160 , 4092},
	{155 , 4075},
	{160 , 4060},
	{160 , 4042},
	{155 , 4023},
	{163 , 4009},
	{165 , 3995},
	{163 , 3983},
	{160 , 3970},
	{165 , 3958},
	{170 , 3946},
	{170 , 3935},
	{173 , 3923},
	{183 , 3913},
	{180 , 3903},
	{185 , 3892},
	{195 , 3885},
	{193 , 3874},
	{195 , 3865},
	{198 , 3857},
	{193 , 3846},
	{178 , 3833},
	{165 , 3820},
	{153 , 3809},  
	{148 , 3800}, 
	{150 , 3793},
	{148 , 3788},
	{150 , 3785},  
	{150 , 3781},
	{148 , 3779},
	{153 , 3778},
	{153 , 3777},
	{155 , 3775},
	{160 , 3774},
	{163 , 3773},
	{165 , 3771},
	{163 , 3770},
	{168 , 3768},
	{165 , 3763},
	{168 , 3758},
	{163 , 3751},
	{163 , 3740},
	{165 , 3731},
	{178 , 3719},
	{185 , 3704},
	{188 , 3683},
	{185 , 3657},
	{180 , 3626},
	{173 , 3598},
	{178 , 3577},
	{188 , 3559},
	{198 , 3536},
	{188 , 3480},
	{203 , 3389},
	{203 , 3389},
	{203 , 3389},
	{203 , 3389} 
};

// r-table profile for actual temperature. The size should be the same as T1, T2 and T3
R_PROFILE_STRUC r_profile_temperature[] =
{	
  {0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },  
	{0  , 0 }, 
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },  
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 },
	{0  , 0 }
};      


int fgauge_get_saddles(void);
BATTERY_PROFILE_STRUC_P fgauge_get_profile(kal_uint32 temperature);

int fgauge_get_saddles_r_table(void);
R_PROFILE_STRUC_P fgauge_get_profile_r_table(kal_uint32 temperature);
