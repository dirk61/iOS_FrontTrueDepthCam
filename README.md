# iOS_FrontTrueDepthCam

An example using ARVideoKit for simultaneous Front Camera TrueDepth Map Capture & Video Recording.



##### Files will be saved at the local directory, including:

* a **MOV** format front camera video (30fps, 1504 * 1128)
* A **zip** file containing the stored depth maps (30fps 640 * 480). Use *ReadDepth.ipynb* in the notebook
* a **txt** file recording the timestamp of each depth frame for future synchronization



<img src="/Users/gix/Downloads/IMG_3964.PNG" alt="IMG_3964" style="zoom:30%;" />



##### Process the zip file of Depth maps

Follow the instructions in the Jupiter notebook. You can retrieve all the frames in arrays and do whatever you want, e.g. generate a depth video.

<img src="/Users/gix/Downloads/Research/GIX/iOS_BackLidarCam/Examples/iOS_BackLidarCam/images/c4009b90-529c-4f15-85d7-924b95d1777c.png"/>