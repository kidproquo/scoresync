We have an online service that accepts a PDF and returns with the detected measures. So when a PDF is selected, let's call this POST API with the file and use the response to draw rectangles. Makse sure we scale the dimensions.

Sample curl call:
`curl -X POST https://dabba.princesamuel.me/symph/upload_and_predict \
    -F "file=@Corrina.pdf"`


Response:
```
{
  "original_filename": "Corrina.pdf",
  "pages": [
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-01.png",
      "page_number": 1,
      "system_measures": [
        {
          "bottom": 1217,
          "left": 159,
          "right": 862,
          "top": 905
        },
        {
          "bottom": 1920,
          "left": 221,
          "right": 886,
          "top": 1429
        },
        {
          "bottom": 697,
          "left": 425,
          "right": 1004,
          "top": 397
        },
        {
          "bottom": 1217,
          "left": 893,
          "right": 1544,
          "top": 897
        },
        {
          "bottom": 1929,
          "left": 855,
          "right": 1493,
          "top": 1438
        },
        {
          "bottom": 704,
          "left": 997,
          "right": 1546,
          "top": 393
        },
        {
          "bottom": 697,
          "left": 159,
          "right": 435,
          "top": 393
        },
        {
          "bottom": 694,
          "left": 994,
          "right": 1544,
          "top": 583
        },
        {
          "bottom": 1208,
          "left": 876,
          "right": 1559,
          "top": 1101
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-02.png",
      "page_number": 2,
      "system_measures": [
        {
          "bottom": 1972,
          "left": 153,
          "right": 893,
          "top": 1470
        },
        {
          "bottom": 695,
          "left": 156,
          "right": 893,
          "top": 196
        },
        {
          "bottom": 1345,
          "left": 150,
          "right": 908,
          "top": 842
        },
        {
          "bottom": 1340,
          "left": 910,
          "right": 1515,
          "top": 837
        },
        {
          "bottom": 1962,
          "left": 903,
          "right": 1541,
          "top": 1859
        },
        {
          "bottom": 686,
          "left": 905,
          "right": 1539,
          "top": 585
        },
        {
          "bottom": 2018,
          "left": 904,
          "right": 1539,
          "top": 1466
        },
        {
          "bottom": 738,
          "left": 901,
          "right": 1544,
          "top": 196
        },
        {
          "bottom": 1325,
          "left": 900,
          "right": 1548,
          "top": 1218
        },
        {
          "bottom": 1867,
          "left": 917,
          "right": 1534,
          "top": 666
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-03.png",
      "page_number": 3,
      "system_measures": [
        {
          "bottom": 1965,
          "left": 156,
          "right": 702,
          "top": 1469
        },
        {
          "bottom": 1328,
          "left": 150,
          "right": 873,
          "top": 838
        },
        {
          "bottom": 705,
          "left": 151,
          "right": 899,
          "top": 199
        },
        {
          "bottom": 738,
          "left": 902,
          "right": 1546,
          "top": 201
        },
        {
          "bottom": 686,
          "left": 901,
          "right": 1544,
          "top": 585
        },
        {
          "bottom": 1982,
          "left": 709,
          "right": 1492,
          "top": 1473
        },
        {
          "bottom": 1322,
          "left": 882,
          "right": 1521,
          "top": 1224
        },
        {
          "bottom": 1382,
          "left": 878,
          "right": 1538,
          "top": 841
        },
        {
          "bottom": 1962,
          "left": 698,
          "right": 1549,
          "top": 1853
        },
        {
          "bottom": 1453,
          "left": 890,
          "right": 1539,
          "top": 241
        },
        {
          "bottom": 1321,
          "left": 154,
          "right": 877,
          "top": 1209
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-04.png",
      "page_number": 4,
      "system_measures": [
        {
          "bottom": 697,
          "left": 152,
          "right": 899,
          "top": 196
        },
        {
          "bottom": 715,
          "left": 904,
          "right": 1545,
          "top": 199
        },
        {
          "bottom": 1971,
          "left": 157,
          "right": 895,
          "top": 1471
        },
        {
          "bottom": 1966,
          "left": 900,
          "right": 1547,
          "top": 1480
        },
        {
          "bottom": 1331,
          "left": 170,
          "right": 891,
          "top": 837
        },
        {
          "bottom": 1396,
          "left": 908,
          "right": 1546,
          "top": 849
        },
        {
          "bottom": 1324,
          "left": 896,
          "right": 1543,
          "top": 1220
        },
        {
          "bottom": 1960,
          "left": 891,
          "right": 1548,
          "top": 1857
        },
        {
          "bottom": 683,
          "left": 901,
          "right": 1516,
          "top": 577
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-05.png",
      "page_number": 5,
      "system_measures": [
        {
          "bottom": 699,
          "left": 155,
          "right": 891,
          "top": 196
        },
        {
          "bottom": 1966,
          "left": 205,
          "right": 1086,
          "top": 1473
        },
        {
          "bottom": 1335,
          "left": 151,
          "right": 903,
          "top": 839
        },
        {
          "bottom": 1324,
          "left": 907,
          "right": 1544,
          "top": 1222
        },
        {
          "bottom": 701,
          "left": 903,
          "right": 1531,
          "top": 200
        },
        {
          "bottom": 1340,
          "left": 900,
          "right": 1525,
          "top": 835
        },
        {
          "bottom": 687,
          "left": 888,
          "right": 1544,
          "top": 585
        },
        {
          "bottom": 1992,
          "left": 1048,
          "right": 1524,
          "top": 1461
        },
        {
          "bottom": 1322,
          "left": 143,
          "right": 898,
          "top": 1207
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-06.png",
      "page_number": 6,
      "system_measures": [
        {
          "bottom": 699,
          "left": 188,
          "right": 913,
          "top": 201
        },
        {
          "bottom": 1290,
          "left": 153,
          "right": 885,
          "top": 979
        },
        {
          "bottom": 712,
          "left": 926,
          "right": 1541,
          "top": 194
        },
        {
          "bottom": 1880,
          "left": 149,
          "right": 886,
          "top": 1580
        },
        {
          "bottom": 1884,
          "left": 902,
          "right": 1267,
          "top": 1784
        },
        {
          "bottom": 1283,
          "left": 896,
          "right": 1543,
          "top": 1154
        },
        {
          "bottom": 1650,
          "left": 894,
          "right": 1550,
          "top": 1588
        },
        {
          "bottom": 1046,
          "left": 890,
          "right": 1545,
          "top": 987
        },
        {
          "bottom": 1886,
          "left": 430,
          "right": 885,
          "top": 1782
        },
        {
          "bottom": 1311,
          "left": 899,
          "right": 1536,
          "top": 971
        },
        {
          "bottom": 1883,
          "left": 1390,
          "right": 1541,
          "top": 1784
        },
        {
          "bottom": 684,
          "left": 925,
          "right": 1542,
          "top": 570
        },
        {
          "bottom": 1884,
          "left": 1246,
          "right": 1417,
          "top": 1782
        },
        {
          "bottom": 1887,
          "left": 573,
          "right": 793,
          "top": 1785
        },
        {
          "bottom": 1283,
          "left": 158,
          "right": 889,
          "top": 1133
        },
        {
          "bottom": 1650,
          "left": 201,
          "right": 883,
          "top": 1588
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-07.png",
      "page_number": 7,
      "system_measures": [
        {
          "bottom": 1253,
          "left": 166,
          "right": 919,
          "top": 766
        },
        {
          "bottom": 1974,
          "left": 155,
          "right": 899,
          "top": 1474
        },
        {
          "bottom": 1970,
          "left": 903,
          "right": 1543,
          "top": 1489
        },
        {
          "bottom": 1254,
          "left": 971,
          "right": 1536,
          "top": 1154
        },
        {
          "bottom": 1290,
          "left": 937,
          "right": 1545,
          "top": 774
        },
        {
          "bottom": 1961,
          "left": 892,
          "right": 1548,
          "top": 1860
        },
        {
          "bottom": 492,
          "left": 169,
          "right": 978,
          "top": 186
        },
        {
          "bottom": 489,
          "left": 1119,
          "right": 1419,
          "top": 386
        },
        {
          "bottom": 488,
          "left": 408,
          "right": 1113,
          "top": 384
        },
        {
          "bottom": 505,
          "left": 805,
          "right": 1540,
          "top": 190
        },
        {
          "bottom": 247,
          "left": 866,
          "right": 1524,
          "top": 191
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-08.png",
      "page_number": 8,
      "system_measures": [
        {
          "bottom": 1972,
          "left": 161,
          "right": 893,
          "top": 1480
        },
        {
          "bottom": 1996,
          "left": 896,
          "right": 1551,
          "top": 1473
        },
        {
          "bottom": 698,
          "left": 152,
          "right": 906,
          "top": 204
        },
        {
          "bottom": 1338,
          "left": 149,
          "right": 907,
          "top": 836
        },
        {
          "bottom": 1346,
          "left": 907,
          "right": 1524,
          "top": 835
        },
        {
          "bottom": 730,
          "left": 897,
          "right": 1552,
          "top": 198
        },
        {
          "bottom": 1322,
          "left": 947,
          "right": 1541,
          "top": 1222
        },
        {
          "bottom": 685,
          "left": 890,
          "right": 1546,
          "top": 584
        },
        {
          "bottom": 1960,
          "left": 894,
          "right": 1548,
          "top": 1859
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-09.png",
      "page_number": 9,
      "system_measures": [
        {
          "bottom": 1335,
          "left": 188,
          "right": 912,
          "top": 833
        },
        {
          "bottom": 1834,
          "left": 152,
          "right": 901,
          "top": 1538
        },
        {
          "bottom": 725,
          "left": 233,
          "right": 1094,
          "top": 202
        },
        {
          "bottom": 1326,
          "left": 930,
          "right": 1514,
          "top": 835
        },
        {
          "bottom": 1852,
          "left": 901,
          "right": 1546,
          "top": 1547
        },
        {
          "bottom": 1322,
          "left": 933,
          "right": 1543,
          "top": 1220
        },
        {
          "bottom": 755,
          "left": 1054,
          "right": 1530,
          "top": 208
        },
        {
          "bottom": 684,
          "left": 1119,
          "right": 1470,
          "top": 592
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-10.png",
      "page_number": 10,
      "system_measures": [
        {
          "bottom": 507,
          "left": 156,
          "right": 882,
          "top": 202
        },
        {
          "bottom": 1953,
          "left": 158,
          "right": 866,
          "top": 1641
        },
        {
          "bottom": 1470,
          "left": 157,
          "right": 874,
          "top": 1158
        },
        {
          "bottom": 973,
          "left": 158,
          "right": 895,
          "top": 678
        },
        {
          "bottom": 979,
          "left": 897,
          "right": 1085,
          "top": 877
        },
        {
          "bottom": 1952,
          "left": 881,
          "right": 1541,
          "top": 1645
        },
        {
          "bottom": 527,
          "left": 909,
          "right": 1547,
          "top": 203
        },
        {
          "bottom": 981,
          "left": 1083,
          "right": 1404,
          "top": 878
        },
        {
          "bottom": 741,
          "left": 905,
          "right": 1545,
          "top": 683
        },
        {
          "bottom": 496,
          "left": 896,
          "right": 1547,
          "top": 369
        },
        {
          "bottom": 1540,
          "left": 908,
          "right": 1542,
          "top": 1170
        },
        {
          "bottom": 980,
          "left": 1407,
          "right": 1545,
          "top": 876
        },
        {
          "bottom": 1461,
          "left": 901,
          "right": 1548,
          "top": 1348
        },
        {
          "bottom": 981,
          "left": 427,
          "right": 781,
          "top": 878
        },
        {
          "bottom": 1944,
          "left": 876,
          "right": 1558,
          "top": 1828
        },
        {
          "bottom": 1583,
          "left": 150,
          "right": 894,
          "top": 170
        },
        {
          "bottom": 980,
          "left": 610,
          "right": 740,
          "top": 877
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-11.png",
      "page_number": 11,
      "system_measures": [
        {
          "bottom": 1973,
          "left": 154,
          "right": 898,
          "top": 1467
        },
        {
          "bottom": 700,
          "left": 156,
          "right": 880,
          "top": 194
        },
        {
          "bottom": 1348,
          "left": 148,
          "right": 908,
          "top": 838
        },
        {
          "bottom": 1971,
          "left": 907,
          "right": 1533,
          "top": 1471
        },
        {
          "bottom": 1322,
          "left": 936,
          "right": 1544,
          "top": 1222
        },
        {
          "bottom": 1358,
          "left": 907,
          "right": 1523,
          "top": 832
        },
        {
          "bottom": 770,
          "left": 891,
          "right": 1536,
          "top": 204
        },
        {
          "bottom": 1961,
          "left": 902,
          "right": 1546,
          "top": 1844
        },
        {
          "bottom": 1412,
          "left": 902,
          "right": 1537,
          "top": 216
        },
        {
          "bottom": 1808,
          "left": 169,
          "right": 891,
          "top": 470
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-12.png",
      "page_number": 12,
      "system_measures": [
        {
          "bottom": 697,
          "left": 153,
          "right": 889,
          "top": 193
        },
        {
          "bottom": 1973,
          "left": 158,
          "right": 871,
          "top": 1471
        },
        {
          "bottom": 1354,
          "left": 149,
          "right": 911,
          "top": 839
        },
        {
          "bottom": 1342,
          "left": 908,
          "right": 1519,
          "top": 832
        },
        {
          "bottom": 762,
          "left": 903,
          "right": 1536,
          "top": 196
        },
        {
          "bottom": 1999,
          "left": 882,
          "right": 1535,
          "top": 1468
        },
        {
          "bottom": 683,
          "left": 900,
          "right": 1543,
          "top": 583
        },
        {
          "bottom": 1323,
          "left": 888,
          "right": 1550,
          "top": 1223
        },
        {
          "bottom": 1958,
          "left": 879,
          "right": 1536,
          "top": 1858
        },
        {
          "bottom": 1828,
          "left": 167,
          "right": 884,
          "top": 525
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-13.png",
      "page_number": 13,
      "system_measures": [
        {
          "bottom": 1291,
          "left": 146,
          "right": 893,
          "top": 990
        },
        {
          "bottom": 696,
          "left": 160,
          "right": 691,
          "top": 198
        },
        {
          "bottom": 716,
          "left": 699,
          "right": 1547,
          "top": 205
        },
        {
          "bottom": 1887,
          "left": 147,
          "right": 869,
          "top": 1587
        },
        {
          "bottom": 1656,
          "left": 899,
          "right": 1549,
          "top": 1590
        },
        {
          "bottom": 1889,
          "left": 899,
          "right": 1525,
          "top": 1787
        },
        {
          "bottom": 1053,
          "left": 896,
          "right": 1546,
          "top": 992
        },
        {
          "bottom": 1286,
          "left": 902,
          "right": 1542,
          "top": 1183
        },
        {
          "bottom": 685,
          "left": 699,
          "right": 1550,
          "top": 583
        },
        {
          "bottom": 1885,
          "left": 755,
          "right": 893,
          "top": 1782
        },
        {
          "bottom": 1288,
          "left": 895,
          "right": 1532,
          "top": 980
        },
        {
          "bottom": 1888,
          "left": 756,
          "right": 894,
          "top": 1593
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-14.png",
      "page_number": 14,
      "system_measures": [
        {
          "bottom": 501,
          "left": 157,
          "right": 866,
          "top": 197
        },
        {
          "bottom": 1540,
          "left": 168,
          "right": 888,
          "top": 1233
        },
        {
          "bottom": 1013,
          "left": 153,
          "right": 892,
          "top": 713
        },
        {
          "bottom": 497,
          "left": 1372,
          "right": 1552,
          "top": 396
        },
        {
          "bottom": 1013,
          "left": 887,
          "right": 1537,
          "top": 717
        },
        {
          "bottom": 1556,
          "left": 882,
          "right": 1526,
          "top": 1233
        },
        {
          "bottom": 500,
          "left": 1031,
          "right": 1363,
          "top": 396
        },
        {
          "bottom": 256,
          "left": 877,
          "right": 1528,
          "top": 201
        },
        {
          "bottom": 1016,
          "left": 509,
          "right": 944,
          "top": 908
        },
        {
          "bottom": 497,
          "left": 879,
          "right": 1057,
          "top": 395
        },
        {
          "bottom": 1532,
          "left": 889,
          "right": 1536,
          "top": 1406
        },
        {
          "bottom": 1014,
          "left": 1057,
          "right": 1368,
          "top": 914
        },
        {
          "bottom": 1024,
          "left": 534,
          "right": 915,
          "top": 716
        },
        {
          "bottom": 1014,
          "left": 1386,
          "right": 1549,
          "top": 913
        },
        {
          "bottom": 1533,
          "left": 159,
          "right": 892,
          "top": 1407
        }
      ],
      "width": 1700
    },
    {
      "height": 2200,
      "image_filename": "Corrina_65cgnXh9kuwQ2csyX8VJNW0001-15.png",
      "page_number": 15,
      "system_measures": [
        {
          "bottom": 995,
          "left": 1062,
          "right": 1540,
          "top": 263
        }
      ],
      "width": 1700
    }
  ],
  "success": true,
  "total_pages": 15
}

```
