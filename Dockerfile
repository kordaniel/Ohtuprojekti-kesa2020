FROM ros:melodic-robot
RUN apt-get update
RUN apt-get -y install python3.7 python-pip
RUN pip install pipenv
RUN mkdir -p /catkin_ws/src/ohtu
WORKDIR /catkin_ws/src/ohtu
COPY Pipfile /catkin_ws/src/ohtu/
COPY Pipfile.lock /catkin_ws/src/ohtu/
RUN pipenv install
COPY . /catkin_ws/src/ohtu/
WORKDIR /catkin_ws
RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && catkin_make"
CMD cd /catkin_ws/src/ohtu && pipenv shell "/bin/bash -c 'source /opt/ros/melodic/setup.bash && source ../../devel/setup.bash && cd rostest && rosrun rostest main.py'"