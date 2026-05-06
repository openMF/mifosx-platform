ARG TAG
FROM openmf/fineract:${TAG}

USER root
RUN apk update && \
    apk add --no-cache \
    fontconfig \
    ttf-dejavu \
    gcompat \
    libretls && \
    fc-cache -f -v && \
    rm -rf /var/cache/apk/*

COPY ./mifos-reporting-libs/*.jar /app/libs/
ENV JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Dsun.java2d.fontpath=/usr/share/fonts"
ENV DISPLAY=""

USER 1000