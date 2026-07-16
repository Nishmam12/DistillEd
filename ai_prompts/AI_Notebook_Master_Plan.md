# AI Notebook - AI Integration Master Plan

**Version:** 1.0

**Status:** AI Integration Phase

**Author:** Nabil

---

# Project Overview

The barebones notepad application has already been completed.

The core note editor, storage system, formatting, and general notebook functionality already exist.

The objective of this project is **NOT** to build another note-taking application.

Instead, the goal is to transform the existing notebook into an **AI-powered learning workspace** where an intelligent tutoring system continuously understands the user's notes and actively assists throughout the learning process.

The notebook should become the primary interface, while AI acts as an invisible assistant working in the background.

---

# Product Vision

Rather than being another AI chatbot, the application should feel like having a personal professor sitting beside the user while they study.

The AI should continuously understand:

- What the user is writing
- What topic is being discussed
- How much the user understands
- Which concepts are missing
- Which concepts the user struggles with
- The user's learning progress
- The user's preferred learning style

Instead of waiting for prompts, the AI should proactively provide assistance whenever it detects opportunities to improve learning.

---

# Primary Objective

Transform an existing notebook into an AI-first learning platform.

The notebook remains the center of the application.

Everything else is built around understanding the notebook.

The AI should become:

- Personal Tutor
- Study Partner
- Research Assistant
- Writing Coach
- Knowledge Organizer

---

# Overall System Architecture

```
                    Existing Notepad
                           │
                           ▼
                 Live Context Engine
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼

   AI Router        Learning Memory      RAG Engine

        │                  │                  │
        └──────────────────┼──────────────────┘
                           ▼

                  AI Provider Layer

      ┌──────────────┬──────────────┬──────────────┐
      │              │              │
 Local Gemma     Cloud Gemma     Frontier APIs
 E2B / E4B       26B / 31B      Gemini / Claude / GPT
```

---

# Core Philosophy

The AI should never own the editor.

Instead, it should observe the editor.

The editor remains responsible for:

- Writing
- Editing
- Saving
- Loading
- Formatting

The AI layer is responsible for:

- Understanding
- Teaching
- Summarizing
- Organizing
- Reasoning
- Remembering
- Searching
- Explaining

This separation makes the architecture modular and maintainable.

---

# Live Context Engine

The Context Engine is the heart of the application.

Every few seconds—or after the user pauses typing—it should analyze the notebook and build a structured understanding of the content.

The Context Engine should extract:

## Current Topic

Example:

Machine Learning

---

## Subtopics

Example:

- Regression
- Classification
- Neural Networks

---

## Important Concepts

Example:

- Gradient Descent
- Entropy
- Information Gain

---

## Named Entities

Example:

- Alan Turing
- TensorFlow
- PyTorch

---

## Definitions

Automatically identify important definitions.

---

## Relationships

Understand how concepts relate.

Example:

```
Machine Learning

↓

Supervised Learning

↓

Regression

↓

Linear Regression
```

---

## Knowledge Gaps

Detect:

- Missing explanations
- Incomplete notes
- Undefined terms
- Missing citations

---

## Learning Progress

Estimate:

- Beginner
- Intermediate
- Advanced

Track progress automatically.

---

# AI Tutor

The tutor should feel like a professor rather than a chatbot.

It should know:

- What the student already understands
- What they frequently forget
- Their preferred explanation style
- Their learning speed
- Their strengths
- Their weaknesses

The tutor should never repeatedly explain concepts that have already been mastered.

---

# AI Features

## Summarization

Generate summaries for:

- Selected text
- Paragraph
- Section
- Page
- Notebook
- Entire course

---

## Explain

Explain selected content using different styles.

Modes:

- Beginner
- Intermediate
- Advanced
- Child
- Visual
- Mathematical
- Real-world analogy

---

## Writing Assistant

Continuously detect:

- Grammar issues
- Clarity problems
- Repetition
- Weak explanations
- Missing references
- Poor organization

Suggest improvements without interrupting the user.

---

## Quiz Generator

Generate:

- Multiple Choice Questions
- True / False
- Fill in the Blank
- Flashcards
- Oral Questions
- Coding Challenges

Difficulty:

- Easy
- Medium
- Hard

---

## Flashcards

Automatically generate flashcards from important concepts.

Support export to Anki or other flashcard systems.

---

## Study Planner

Generate:

- 7-day plan
- 14-day plan
- 30-day plan
- Semester study plan
- Exam countdown schedule

---

## Knowledge Graph

Automatically build concept maps from notebook content.

---

## Research Assistant

Help users:

- Find additional sources
- Explain papers
- Compare concepts
- Suggest references
- Generate citations

---

# Long-Term Learning Memory

Instead of remembering conversations, the AI remembers learning progress.

Store:

- Topics learned
- Weak concepts
- Mastered concepts
- Quiz scores
- Study history
- Preferred explanation style
- Learning pace
- Frequently forgotten concepts

The tutor should become increasingly personalized over time.

---

# Retrieval-Augmented Generation (RAG)

Large notebooks should never be sent entirely to the LLM.

Pipeline:

```
Notebook

↓

Chunking

↓

Embedding Model

↓

Vector Database

↓

Semantic Search

↓

Relevant Chunks

↓

LLM
```

Benefits:

- Faster responses
- Lower API cost
- Better accuracy
- Unlimited notebook size

---

# Multi-Tier AI Architecture

## Tier 1 — Local AI

Primary models:

- Gemma 4 E2B
- Gemma 4 E4B

These models are designed for mobile and edge devices, supporting efficient local inference with long-context capabilities.

Responsibilities:

- Grammar
- Rewrite
- Paragraph summaries
- Flashcards
- Short explanations
- Autocomplete
- Local tutoring

Advantages:

- Offline
- Fast
- Private
- No API cost

---

## Tier 2 — Cloud AI

Primary models:

- Gemma 4 26B A4B
- Gemma 4 31B

The 26B A4B Mixture-of-Experts model activates only a subset of its parameters during inference, providing stronger reasoning with much better efficiency than a similarly sized dense model.

Responsibilities:

- Notebook summarization
- Research assistance
- Long-context reasoning
- Semester planning
- Assignment help
- Large document analysis

---

## Tier 3 — Frontier Models

Optional providers:

- Gemini
- Claude
- GPT

Use only when advanced reasoning is required.

Examples:

- Thesis writing
- Research synthesis
- Advanced mathematics
- Large codebases
- Multi-document reasoning

The provider layer should remain modular so any AI service can be added or replaced in the future.

---

# Intelligent AI Router

The router automatically decides which model to use.

Decision factors:

- Task complexity
- Context size
- Latency
- Privacy
- API cost
- Internet availability
- Battery level (mobile)

Example routing:

```
Grammar
↓

Local Gemma

Rewrite Paragraph
↓

Local Gemma

Summarize Notebook
↓

Gemma 26B

Research Assistance
↓

Gemma 31B

Thesis Writing
↓

Claude

Complex Scientific Reasoning
↓

Gemini

Large Codebase Analysis
↓

GPT
```

The user should never manually choose models.

---

# Tool Calling

The AI should support external tools.

Examples:

- Web Search
- Wikipedia
- arXiv
- YouTube
- PDF Reader
- OCR
- Calculator
- Code Execution
- Diagram Generator
- Citation Manager
- Calendar
- Flashcard Export

Future tools should be addable without changing the core architecture.

---

# Privacy

Follow a Local-First architecture.

Rules:

- Prefer local inference whenever possible.
- Only use cloud models when necessary.
- Never upload private notes without user permission.
- Clearly indicate when cloud AI is being used.

---

# Future Roadmap

## Phase 1

- Local AI
- Summaries
- Explanations
- Flashcards
- Quizzes

## Phase 2

- Learning Memory
- RAG
- Knowledge Graph
- Study Planner

## Phase 3

- Cloud AI
- Multi-Agent Tutoring
- Plugin Marketplace
- Classroom Collaboration

## Phase 4

- Voice Tutor
- Vision Understanding
- Whiteboard Analysis
- AI Research Assistant

---

# Implementation Note (added when converting this plan into execution prompts)

This master plan is the product vision. The actual execution was split into phased, loop-engineered prompts (see `00_README_HOW_TO_USE.md` in this folder) with the following scope decisions locked in during planning:

- **Local-first stays local-first.** Isar remains the only on-device data store. No cloud note storage, sync, or authentication is introduced.
- **The "Backend Architecture" / "API Design" / "Database Schema" asks from the original Claude Prompt below are scoped down to a minimal, stateless FastAPI AI Gateway** whose only job is routing to cloud-tier models (Gemma 26B/31B, optional Gemini/Claude/GPT). It is explicitly designed so Supabase (Postgres, Auth, Storage, pgvector) can be added later without a rewrite, but that integration is not built yet.
- **Platform scope is Android-only for now**, matching the current repo (no `ios/` directory exists).
- **Handwriting-to-text is a required, load-bearing addition not covered by the original plan.** InkFlow stores notes as ink strokes and typed text boxes, not plain text — the Context Engine cannot function without an on-device handwriting recognition step feeding it. This is Phase 0 of the execution prompts.

---

# Claude Prompt

You are the Lead AI Systems Architect for an existing note-taking application.

The note editor is already fully built. Do NOT redesign or replace it.

Treat the editor as a completed component.

Your responsibility is to design and implement a production-ready AI layer around the existing notebook.

The notebook should become an AI-powered learning workspace where the AI continuously understands everything the user writes and acts as a personalized tutor.

The architecture must include:

- Live Context Engine
- Intelligent Model Router
- Local-first AI using Gemma 4 E2B and E4B
- Cloud reasoning using Gemma 4 26B A4B and 31B
- Optional routing to Gemini, Claude, and GPT for advanced reasoning
- Long-Term Learning Memory
- Retrieval-Augmented Generation (RAG)
- AI Sidebar
- Writing Assistant
- Quiz Generator
- Flashcards
- Study Planner
- Knowledge Graph
- Tool Calling
- Offline support
- Cross-platform support
- Privacy-first architecture
- Streaming responses
- Modular provider abstraction
- Production-grade scalability

Design the project as if it will become one of the world's best AI-powered educational notebook applications.

Provide:

1. Complete System Architecture
2. Component Diagram
3. Database Schema
4. Backend Architecture
5. API Design
6. Context Engine Design
7. Memory Architecture
8. RAG Pipeline
9. Intelligent AI Router
10. Mobile Optimization Strategy
11. Security Model
12. Cost Optimization Strategy
13. Scalability Roadmap
14. Future Feature Roadmap
15. Implementation milestones with recommended technologies and best practices.

Focus on production-ready engineering decisions instead of high-level feature descriptions.

> Note: as executed, items 3/4/5 (Database Schema, Backend Architecture, API Design) above were deliberately scoped down per the locked-in decisions noted before this prompt — see the phase files for what was actually built instead of the full backend originally described here.
