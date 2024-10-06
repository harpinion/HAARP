# HAARP Scanner

This project will give the possibility to search and prove the existance of HAARP.  
It will describe how an simple automated station for measurements can be build.  
With this software the activity is recorded and illustrated in daily heatmap graphics.  
A short description in german and english is included.
This includes links and a circuit diagram for the hardware / receiver.


The standard directory for running haarpscan is **/srv/SDR/**  


Directory | Content
----------- | ----------
archive | archive for raw csv-data of the measurements
daily | daily images of the generated heatmaps
tmp | temporary files of the day
week | weekly images of the heatmaps (manual generation with -w)
examples | some old examples


In the directory week you will find an overview of the measurements of the last years.
Additionally you will find locally measured weather data from the same place as the receiver of the HAARP radio waves.
The location is in the region cologne in germany.

All the measured source data (archive) from 2017 - 2023 is 142 GB packed data.
The generated daily images (waterfal diagrams as png files) are now 201 GB of data.

**Update 2024:**

There is no longer a converter as special hardware needed, to build up a HAARP Scanner with this software.
There are now cheap RTL-SDR dongles like the **Nooelec NESDR SMArt**, that can direct receive from 100 kHz up to 1750 MHz, please read the description [here](https://github.com/harpinion/HAARP/issues/1#issuecomment-2389185884).
