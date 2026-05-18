# Build docker image
sudo docker build -t iot_dev_environment_image .

# Create docker container
sudo docker run -it --name iot_dev_environment -v /home/callanor/Dropbox/puj/iot/learnerLabCode:/app iot_dev_environment_image bash

# Create docker detach 
sudo docker run -d --name iot_dev_environment -v /home/callanor/Dropbox/puj/iot/learnerLabCode:/app iot_dev_environment_image

# ssh into docker container
sudo docker exec -ti --name iot_dev_environment bash


# Configure AWS CLI in docker container
1. Launch Learner Lab
2. In the prompt cat .aws/credentials
3. In the docker container: aws configure
    - use the learnerLab credentials
4. In /root/.aws/credentials put the learnerLab credentials
4. Test, aws s3 ls