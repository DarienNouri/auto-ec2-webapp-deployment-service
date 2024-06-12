

# EC2 Web App Deployment Service

Deploying web apps on EC2 instances was getting annoying, so I built this.


## Architecture

1. **Webhook**: The EC2 instance listens for webhook events from GitHub, triggered by pushes to the repository.
2. **Deployment Script**: Upon receiving a webhook event, the deployment script automatically pulls the latest code from the GitHub repository and deploys it to the EC2 instance.


### Deploy an Application

1. Push changes to the application's GitHub repo.
2. The EC2 instance listens for webhook events from GitHub.
3. Upon receiving a push event, the instance pulls the latest code and deploys the application.

### Manage Deployed Applications

relevant PM2 usage:

```bash
# List running apps
pm2 list

# View logs
pm2 logs <app-name>

# Restart an app
pm2 restart <app-name>
```

The deployed applications are served via Nginx as a reverse proxy.



## Implementation in App Code

To use the `dash-ec2-wrapper` in Dash, install with:
```bash
pip install git+https://github.com/DarienNouri/dash-ec2-wrapper.git
```

Then, import and use as normal:

```python
from dash_ec2_wrapper import Dash

app = Dash(__name__)
# ...
```
