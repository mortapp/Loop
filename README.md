# LOOP

LOOP is an AI-powered value operating system designed to help people and businesses:

- MAKE value
- PROTECT value
- RECOVER value

Initial engines:

- QuoteCloser
- ReturnGuard
- ResellLens

## Core lifecycle

EARN -> BUY -> OWN -> RETURN / RESELL -> EARN AGAIN

## Planned stack

### Mobile
Flutter + Dart

### Web
Next.js + TypeScript

### Backend
Supabase + PostgreSQL + Auth + RLS + Storage

## Repository

This repository contains the shared LOOP platform.

The initial project architecture is being built as a modular monolith rather than separate applications.

## Clients

- `apps/web` — LOOP's web client.
- `apps/mobile` — the retained Flutter mobile client (including its Flutter iOS project).
- `apps/ios-native` — the separate native SwiftUI iOS client. It uses the same LOOP Supabase project and awaits macOS/Xcode runtime certification.
