FROM python:3.6

COPY app /usr/src/app
RUN pip3 install -r /usr/src/app/requirements.txt

EXPOSE 8000

CMD /usr/local/bin/uwsgi --http 0.0.0.0:8000 --wsgi-file  /usr/src/app/service.py --callable __hug_wsgi__
