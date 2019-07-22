#!/usr/bin/env python2
# -*- coding: utf-8 -*-
' tpch compute tools '

__author__ = 'Fengming Wang'

import sys
import csv
import math

class Mycsv(csv.excel):
	delimiter = ";"

def compute_power1(qs, us, factor):
    log_query_summary = 0.0
    for _, value in enumerate(qs):
        log_query_summary += math.log(value)
    log_update_summary = 0.0
    for _, value in enumerate(us):
        log_update_summary += math.log(value)
    power = 3600* math.exp((-1/24.0) * (log_query_summary + log_update_summary)) * factor
    print "power is:%f" % power

def compute_power2(qs, us, factor):
    jh_query_summary = 1.0
    for _, value in enumerate(qs):
        jh_query_summary *= value
    jh_update_summary = 1.0
    for _, value in enumerate(us):
        jh_update_summary *= value
    
    power = 3600  * factor / math.pow(jh_query_summary * jh_update_summary, 1/24.0)
    print "power is:%f" % power    

def compute():
    args = sys.argv
    if len(args)!= 2:
      print "usage python compute.py <csv_path>"
      return

    print "starting to comopute tpch results:"
    csv.register_dialect('mycsv',Mycsv)
    qs = []
    with open(args[1]) as csvfile: 
        csv_reader = csv.DictReader(csvfile, dialect="mycsv")
        for row in csv_reader:
            for k, v in row.items():
                if k is not None:
                    if k.startswith("query") and (not k.endswith("hash")):
                        qs.append(float(v))
    us =[]
    compute_power1(qs, us, 1)  
    compute_power2(qs, us, 1)     

if __name__=='__main__':
    compute()
